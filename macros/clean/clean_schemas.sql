{% macro clean_schemas(database=target.database, dry_run=True) %}
    {% set snowflake_schemas_to_drop = [] %}
    {% set nodes = graph.nodes.values() if graph.nodes else [] %}
    {% set sources = graph.sources.values() if graph.sources else [] %}

    {% set get_schemas %}
        SELECT DISTINCT table_schema
        FROM {{ database }}.information_schema.tables
        WHERE table_schema NOT IN ('INFORMATION_SCHEMA', 'META', 'PUBLIC', 'PUBLIC_META', 'SCHEMACHANGE', 'UNIT_TESTS')
    {% endset %}

    {% set snowflake_schema_results = run_query(get_schemas).columns[0].values() %}
    {% for schema in snowflake_schema_results %}
        {% set dbt_schemas = [] %}
        {% set matching_nodes = nodes | selectattr("schema", "equalto", schema | lower) %}
        {% for node in matching_nodes %}
            {% do dbt_schemas.append(node.schema) %}
        {% endfor %}
        {% if dbt_schemas | length == 0 %}
            {% set matching_nodes = sources | selectattr("schema", "equalto", schema | lower) %}
            {% for node in matching_nodes %}
                {% do dbt_schemas.append(node.schema) %}
            {% endfor %}
        {% endif %}
        {% if dbt_schemas | length == 0 %}
            {% do snowflake_schemas_to_drop.append(schema) %}
        {% endif %}
    {% endfor %}

    {% do dbt_dataengineers_utils.drop_object("SCHEMA", database, snowflake_schemas_to_drop, dry_run) %}
{% endmacro %}
