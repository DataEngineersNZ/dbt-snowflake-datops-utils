{% macro clean_data_metric_functions(database=target.database, dry_run=True) %}
    {% if execute %}
    {% set snowflake_dmfs_to_drop = [] %}
    {% set nodes = graph.nodes.values() if graph.nodes else [] %}

    {% set get_snowflake_dmfs %}
        SELECT
            function_schema AS schema,
            function_name AS name,
            argument_signature AS argument_signature
        FROM {{ database }}.information_schema.functions
        WHERE is_data_metric = 'YES'
        AND function_schema NOT IN ('INFORMATION_SCHEMA', 'META', 'PUBLIC', 'PUBLIC_META', 'SCHEMACHANGE', 'UNIT_TESTS')
    {% endset %}

    {% set snowflake_dmf_results = run_query(get_snowflake_dmfs) %}

    {% for result in snowflake_dmf_results %}
        {% set dbt_models = [] %}
        {% set sql_object_schema = result.values()[0] %}
        {% set sql_object_name = result.values()[1] %}
        {% set sql_arguments = result.values()[2] %}

        {# Match against dbt graph nodes with materialized='data_metric_function' #}
        {# Uses selectattr for materialized check (consistent with clean_generic) #}
        {# Then checks both node.name and override_name (consistent with has_matching_nodes) #}
        {% set matching_nodes = nodes
            | selectattr("schema", "equalto", sql_object_schema | lower)
            | selectattr("config.materialized", "equalto", "data_metric_function")
        %}
        {% for node in matching_nodes %}
            {% set node_name = node.config.get("meta", {}).get("override_name", node.config.get("override_name", node.name)) %}
            {% if node_name | lower == sql_object_name | lower %}
                {% do dbt_models.append(node.schema ~ "." ~ node.name) %}
            {% endif %}
        {% endfor %}

        {% if dbt_models | length == 0 %}
            {% do snowflake_dmfs_to_drop.append(sql_object_schema ~ "." ~ sql_object_name ~ sql_arguments) %}
        {% endif %}
    {% endfor %}

    {% do dbt_dataengineers_utils.drop_object("FUNCTION", database, snowflake_dmfs_to_drop, dry_run) %}
    {% endif %}
{% endmacro %}
