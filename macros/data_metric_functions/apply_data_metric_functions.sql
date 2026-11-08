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
       as single-quoted SQL literals with backslashes and embedded single quotes escaped
       (backslashes first, so a literal `\` in the value isn't later misread as the start of
       an escape sequence by Snowflake's string literal parser); numeric values are rendered
       unquoted, so the generated `IN (...)` clause is valid SQL either way.

    2. Custom DMFs (authored via the `dbt_dataengineers_materializations.data_metric_function`
       materialization), via a model-level `meta.dmf_custom` list (set under `config.meta` at
       the model level, not per-column):
         dmf_custom:
           - ref: my_custom_dmf_model     # the dbt model name materialized as data_metric_function
             columns: [col1, col2]        # columns passed positionally into its TABLE argument
             expectation_name: my_check   # optional; omit to attach without an expectation
             expectation_value: 0         # optional; defaults to 0 when expectation_name is set

       The custom DMF's actual relation (database/schema/name) is resolved via
       `builtins.ref(entry.ref)` (dbt's unmodified ref, bypassing any project-level `ref()`
       override, so the DMF's true fully-qualified relation is always used regardless of a
       consuming project's own ref override behavior) rather than assumed, so renames/
       relocations of the DMF model are picked up automatically. This resolution happens
       unconditionally (not only when `execute` is true) specifically so dbt's parser records
       the DAG dependency during manifest compilation -- without it, dbt has no guarantee the
       custom DMF is built before this model's post-hook tries to attach it.

       On dbt-core specifically (not dbt-fusion), this `ref()`-inside-a-macro pattern is NOT
       enough on its own: dbt-core's static dependency inference only scans the model's own
       .sql file text for literal `ref()` calls, and can't trace one that lives inside a macro
       invoked indirectly via `post_hook`. Any model using `meta.dmf_custom` must also add an
       explicit hint as the first line of its .sql file, naming every referenced custom DMF:
         -- depends_on: {{ ref('my_custom_dmf_model') }}
       Without this, dbt-core raises "dbt was unable to infer all dependencies" at compile
       time. See `integration_tests/models/data_metric_functions/test_dmf_custom_target.sql`
       for a working example.

    Sets DATA_METRIC_SCHEDULE on the object once per run before attaching any DMF, since a
    freshly (re)created object has no schedule set yet. Resolved in this order:
      1. the model's own `config.meta.dmf_schedule` (per-model override)
      2. the `dmf_schedule` var (project-wide default, set in `dbt_project.yml` or `--vars`)
      3. '60 MINUTE' (hardcoded fallback if neither of the above is set)

    Supported materializations: `table`, `view`, `materialized_view`. All three are fully
    recreated (`CREATE OR REPLACE`) on every run, which is what makes "unconditionally ADD
    every configured DMF on every run" safe -- Snowflake drops all prior DMF bindings as part
    of that recreation, so there's nothing to reconcile and no removed-from-meta binding can
    linger. Deliberately NOT supported: `incremental`, `snapshot`, or any other materialization
    that persists the same physical object across runs -- on a persisted object, a second run
    would try to ADD a binding that's already attached and Snowflake would reject it. Calling
    this macro on an unsupported materialization raises a clear compiler error rather than
    guessing and failing later with an obscure Snowflake error.

    `materialized_view` needs two different ALTER keywords, not one: Snowflake requires
    `ALTER MATERIALIZED VIEW` to set `DATA_METRIC_SCHEDULE`, but `ALTER VIEW` (not `ALTER
    MATERIALIZED VIEW`) to ADD/DROP a DMF binding. The macro resolves these separately.

    Identifiers are rendered with dbt's actual quoting, not blindly uppercased: the target
    relation uses `this` (dbt's own correctly-quoted reference to the current model), and
    each column uses `adapter.quote(column)` only when that column's `quote: true` is set
    (matching dbt's own quoting convention), otherwise the plain column name -- Snowflake
    resolves an unquoted identifier case-insensitively, so no uppercasing is needed there
    either. `dmf_custom` column names are the one exception: they're taken from `meta` as
    given, with no quoting applied, since there's no per-column quote metadata to consult
    for a name supplied through a custom DMF's `columns` list -- pass an already-quoted
    string (e.g. `'"CustomerId"'`) there if the referenced column is case-sensitive.
-#}
    {%- set materialization_map = {
        "table": {"schedule": "table", "dmf": "table"},
        "view": {"schedule": "view", "dmf": "view"},
        "materialized_view": {"schedule": "materialized view", "dmf": "view"}
    } -%}
    {%- set model_materialized = model.config.get("materialized") -%}
    {%- set materialization = materialization_map.get(model_materialized) -%}
    {%- set schedule_materialization = materialization.get("schedule") if materialization else none -%}
    {%- set dmf_materialization = materialization.get("dmf") if materialization else none -%}
    {%- set model_schema = model.schema | upper -%}
    {%- set model_alias = model.alias | upper -%}
    {%- set relation_reference = this -%}
    {%- set model_meta = model.config.get("meta", {}) -%}
    {%- set custom_dmfs = model_meta.get("dmf_custom", []) -%}

    {#- Resolved unconditionally (outside any `execute` guard) so dbt's parser records the
       DAG dependency on every custom DMF model, regardless of a project-level ref() override. -#}
    {%- set custom_dmf_relations = {} -%}
    {% for custom_dmf in custom_dmfs %}
        {%- do custom_dmf_relations.update({custom_dmf["ref"]: builtins.ref(custom_dmf["ref"])}) -%}
    {% endfor %}

    {%- set columns_with_dmf = [] -%}
    {% for column in model.columns %}
        {%- set column_meta = model.columns[column].config.get("meta", {}) if model.columns[column].config is defined else model.columns[column].get("meta", {}) -%}
        {% if column_meta.get("dmf_not_null") or column_meta.get("dmf_unique") or column_meta.get("dmf_accepted_values") %}
            {%- do columns_with_dmf.append(column) -%}
        {% endif %}
    {% endfor %}

    {% if columns_with_dmf | length > 0 or custom_dmfs | length > 0 %}
        {% if materialization is none %}
            {{ exceptions.raise_compiler_error(
                "apply_data_metric_functions: unsupported materialized='" ~ model_materialized ~ "' for model " ~ model.unique_id ~
                ". Only " ~ materialization_map.keys() | join(', ') ~ " are supported -- this macro unconditionally re-ADDs every" ~
                " configured DMF on each run, which only works for materializations that are fully recreated (CREATE OR REPLACE)" ~
                " every run. incremental/snapshot-style materializations persist the same object, so a second run would try to ADD" ~
                " a binding that is already attached and Snowflake would reject it."
            ) }}
        {% endif %}
        {% if execute %}
            {{ log("Applying data metric functions for " ~ model_schema | lower ~ "." ~ model_alias | lower, info=True) }}

            {%- set dmf_schedule = model_meta.get("dmf_schedule", var("dmf_schedule", "60 MINUTE")) -%}
            {%- call statement("set_dmf_schedule", fetch_result=True) -%}
                alter {{ schedule_materialization }} {{ relation_reference }} set data_metric_schedule = '{{ dmf_schedule }}'
            {%- endcall -%}

            {% for column in columns_with_dmf %}
                {%- set column_meta = model.columns[column].config.get("meta", {}) if model.columns[column].config is defined else model.columns[column].get("meta", {}) -%}
                {%- set column_identifier = adapter.quote(column) if model.columns[column].get("quote") else column -%}
                {%- set expectation_prefix = model_alias | lower ~ "_" ~ column | lower -%}

                {% if column_meta.get("dmf_not_null") %}
                    {%- call statement("dmf_not_null_" ~ column, fetch_result=True) -%}
                        alter {{ dmf_materialization }} {{ relation_reference }}
                            add data metric function snowflake.core.null_count
                            on ({{ column_identifier }})
                            expectation {{ expectation_prefix }}_not_null (value = 0)
                    {%- endcall -%}
                {% endif %}

                {% if column_meta.get("dmf_unique") %}
                    {%- call statement("dmf_unique_" ~ column, fetch_result=True) -%}
                        alter {{ dmf_materialization }} {{ relation_reference }}
                            add data metric function snowflake.core.duplicate_count
                            on ({{ column_identifier }})
                            expectation {{ expectation_prefix }}_unique (value = 0)
                    {%- endcall -%}
                {% endif %}

                {% if column_meta.get("dmf_accepted_values") %}
                    {%- set accepted_values_list = column_meta.get("dmf_accepted_values") -%}
                    {%- set accepted_values_literals = [] -%}
                    {%- for accepted_value in accepted_values_list -%}
                        {%- if accepted_value is string -%}
                            {%- set escaped_value = accepted_value | replace("\\", "\\\\") | replace("'", "''") -%}
                            {%- do accepted_values_literals.append("'" ~ escaped_value ~ "'") -%}
                        {%- else -%}
                            {%- do accepted_values_literals.append(accepted_value | string) -%}
                        {%- endif -%}
                    {%- endfor -%}
                    {%- set accepted_values_sql = accepted_values_literals | join(", ") -%}
                    {%- call statement("dmf_accepted_values_" ~ column, fetch_result=True) -%}
                        alter {{ dmf_materialization }} {{ relation_reference }}
                            add data metric function snowflake.core.accepted_values
                            on ({{ column_identifier }}, {{ column_identifier }} -> {{ column_identifier }} in ({{ accepted_values_sql }}))
                            expectation {{ expectation_prefix }}_accepted_values (value = 0)
                    {%- endcall -%}
                {% endif %}
            {% endfor %}

            {% for custom_dmf in custom_dmfs %}
                {%- set custom_dmf_relation = custom_dmf_relations[custom_dmf["ref"]] -%}
                {%- set custom_dmf_columns = custom_dmf.get("columns", []) | join(", ") -%}
                {%- set custom_dmf_statement_name = "dmf_custom_" ~ custom_dmf["ref"] -%}
                {% if custom_dmf.get("expectation_name") %}
                    {%- set custom_dmf_expectation_value = custom_dmf.get("expectation_value", 0) -%}
                    {%- call statement(custom_dmf_statement_name, fetch_result=True) -%}
                        alter {{ dmf_materialization }} {{ relation_reference }}
                            add data metric function {{ custom_dmf_relation }}
                            on ({{ custom_dmf_columns }})
                            expectation {{ custom_dmf["expectation_name"] }} (value = {{ custom_dmf_expectation_value }})
                    {%- endcall -%}
                {% else %}
                    {%- call statement(custom_dmf_statement_name, fetch_result=True) -%}
                        alter {{ dmf_materialization }} {{ relation_reference }}
                            add data metric function {{ custom_dmf_relation }}
                            on ({{ custom_dmf_columns }})
                    {%- endcall -%}
                {% endif %}
            {% endfor %}
        {% endif %}
    {% endif %}
{% endmacro %}


