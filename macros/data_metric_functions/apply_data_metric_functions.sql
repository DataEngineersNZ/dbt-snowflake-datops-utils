{% macro apply_data_metric_functions() %}
{#-
    Attaches Snowflake Data Metric Functions (DMFs) to a model based on `meta` flags, as a
    post-hook (NOT a one-off ALTER). This matters because `CREATE OR REPLACE TABLE|VIEW`
    replaces the previous object and drops any previously attached DMF bindings from scratch
    (confirmed in Snowflake docs). Running this as a post-hook re-attaches the DMFs every
    run, so the bindings never go stale.

    Supports two kinds of DMF:

    1. System DMFs, via per-column `meta` keys (set under `config.meta` in the column's YAML):
         dmf_not_null: true           -> SNOWFLAKE.CORE.NULL_COUNT,      expectation VALUE = 0
         dmf_unique: true             -> SNOWFLAKE.CORE.DUPLICATE_COUNT, expectation VALUE = 0
         dmf_accepted_values: [...]   -> SNOWFLAKE.CORE.ACCEPTED_VALUES, expectation VALUE = 0

       `dmf_unique` should only be set on columns that are genuinely unique in the
       materialized object -- e.g. the primary key of a `merge`/upsert-style model. Setting
       it on a column that legitimately repeats (e.g. an append-only history/staging grain)
       will surface a real (expected) `DUPLICATE_COUNT` violation, not a bug in this macro.

       `dmf_accepted_values` accepts a mix of strings and numbers; string values are rendered
       as single-quoted SQL literals (with embedded single quotes escaped), numeric values
       are rendered unquoted, so the generated `IN (...)` clause is valid SQL either way.

    2. Custom DMFs (authored via the `dbt_dataengineers_materializations.data_metric_function`
       materialization), via a model-level `meta.dmf_custom` list (set under `config.meta` at
       the model level, not per-column):
         dmf_custom:
           - ref: my_custom_dmf_model     # the dbt model name materialized as data_metric_function
             columns: [col1, col2]        # columns passed positionally into its TABLE argument
             expectation_name: my_check   # optional; omit to attach without an expectation
             expectation_value: 0         # optional; defaults to 0 when expectation_name is set

       The custom DMF's actual relation (database/schema/name) is resolved via `ref(entry.ref)`
       rather than assumed, so renames/relocations of the DMF model are picked up automatically.
       Referencing it via `ref()` inside this post-hook also establishes the dbt DAG dependency,
       so the custom DMF is guaranteed to exist before this model's post-hook tries to attach it.

    Sets DATA_METRIC_SCHEDULE on the object once per run before attaching any DMF, since a
    freshly (re)created object has no schedule set yet. Resolved in this order:
      1. the model's own `config.meta.dmf_schedule` (per-model override)
      2. the `dmf_schedule` var (project-wide default, set in `dbt_project.yml` or `--vars`)
      3. '60 MINUTE' (hardcoded fallback if neither of the above is set)
-#}
    {% if execute %}
        {%- set materialization_map = {"table": "table", "view": "view", "incremental": "table", "snapshot": "table", "immutable_table": "table", "materialized_view": "view"} -%}
        {%- set materialization = materialization_map.get(model.config.get("materialized"), "view") -%}
        {%- set model_schema = model.schema | upper -%}
        {%- set model_alias = model.alias | upper -%}
        {%- set relation_reference = model.database ~ "." ~ model_schema ~ "." ~ model_alias -%}
        {%- set model_meta = model.config.get("meta", {}) -%}
        {%- set custom_dmfs = model_meta.get("dmf_custom", []) -%}

        {%- set columns_with_dmf = [] -%}
        {% for column in model.columns %}
            {%- set column_meta = model.columns[column].config.get("meta", {}) if model.columns[column].config is defined else model.columns[column].get("meta", {}) -%}
            {% if column_meta.get("dmf_not_null") or column_meta.get("dmf_unique") or column_meta.get("dmf_accepted_values") %}
                {%- do columns_with_dmf.append(column) -%}
            {% endif %}
        {% endfor %}

        {% if columns_with_dmf | length > 0 or custom_dmfs | length > 0 %}
            {{ log("Applying data metric functions for " ~ model_schema | lower ~ "." ~ model_alias | lower, info=True) }}

            {%- set dmf_schedule = model_meta.get("dmf_schedule", var("dmf_schedule", "60 MINUTE")) -%}
            {%- call statement("set_dmf_schedule", fetch_result=True) -%}
                alter {{ materialization }} {{ relation_reference }} set data_metric_schedule = '{{ dmf_schedule }}'
            {%- endcall -%}

            {% for column in columns_with_dmf %}
                {%- set column_meta = model.columns[column].config.get("meta", {}) if model.columns[column].config is defined else model.columns[column].get("meta", {}) -%}
                {%- set column_upper = column | upper -%}
                {%- set expectation_prefix = model_alias | lower ~ "_" ~ column | lower -%}

                {% if column_meta.get("dmf_not_null") %}
                    {%- call statement("dmf_not_null_" ~ column, fetch_result=True) -%}
                        alter {{ materialization }} {{ relation_reference }}
                            add data metric function snowflake.core.null_count
                            on ({{ column_upper }})
                            expectation {{ expectation_prefix }}_not_null (value = 0)
                    {%- endcall -%}
                {% endif %}

                {% if column_meta.get("dmf_unique") %}
                    {%- call statement("dmf_unique_" ~ column, fetch_result=True) -%}
                        alter {{ materialization }} {{ relation_reference }}
                            add data metric function snowflake.core.duplicate_count
                            on ({{ column_upper }})
                            expectation {{ expectation_prefix }}_unique (value = 0)
                    {%- endcall -%}
                {% endif %}

                {% if column_meta.get("dmf_accepted_values") %}
                    {%- set accepted_values_list = column_meta.get("dmf_accepted_values") -%}
                    {%- set accepted_values_literals = [] -%}
                    {%- for accepted_value in accepted_values_list -%}
                        {%- if accepted_value is string -%}
                            {%- do accepted_values_literals.append("'" ~ accepted_value | replace("'", "''") ~ "'") -%}
                        {%- else -%}
                            {%- do accepted_values_literals.append(accepted_value | string) -%}
                        {%- endif -%}
                    {%- endfor -%}
                    {%- set accepted_values_sql = accepted_values_literals | join(", ") -%}
                    {%- call statement("dmf_accepted_values_" ~ column, fetch_result=True) -%}
                        alter {{ materialization }} {{ relation_reference }}
                            add data metric function snowflake.core.accepted_values
                            on ({{ column_upper }}, {{ column_upper }} -> {{ column_upper }} in ({{ accepted_values_sql }}))
                            expectation {{ expectation_prefix }}_accepted_values (value = 0)
                    {%- endcall -%}
                {% endif %}
            {% endfor %}

            {% for custom_dmf in custom_dmfs %}
                {%- set custom_dmf_relation = ref(custom_dmf["ref"]) -%}
                {%- set custom_dmf_columns = custom_dmf.get("columns", []) | map("upper") | join(", ") -%}
                {%- set custom_dmf_statement_name = "dmf_custom_" ~ custom_dmf["ref"] -%}
                {% if custom_dmf.get("expectation_name") %}
                    {%- set custom_dmf_expectation_value = custom_dmf.get("expectation_value", 0) -%}
                    {%- call statement(custom_dmf_statement_name, fetch_result=True) -%}
                        alter {{ materialization }} {{ relation_reference }}
                            add data metric function {{ custom_dmf_relation }}
                            on ({{ custom_dmf_columns }})
                            expectation {{ custom_dmf["expectation_name"] }} (value = {{ custom_dmf_expectation_value }})
                    {%- endcall -%}
                {% else %}
                    {%- call statement(custom_dmf_statement_name, fetch_result=True) -%}
                        alter {{ materialization }} {{ relation_reference }}
                            add data metric function {{ custom_dmf_relation }}
                            on ({{ custom_dmf_columns }})
                    {%- endcall -%}
                {% endif %}
            {% endfor %}
        {% endif %}
    {% endif %}
{% endmacro %}

