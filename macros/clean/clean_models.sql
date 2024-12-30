{% macro clean_models(database=target.database, dry_run=True) %}
    {% set snowflake_views_to_drop = [] %}
    {% set snowflake_tables_to_drop = [] %}
    {% set snowflake_dynamic_tables_to_drop = [] %}
    {% set snowflake_external_tables_to_drop = [] %}
    {% set nodes = graph.nodes.values() if graph.nodes else [] %}
    {% set sources = graph.sources.values() if graph.sources else [] %}

    {% set get_snowflake_models %}
        SELECT
            CASE
                WHEN is_dynamic = 'YES' THEN 'DYNAMIC TABLE'
                WHEN is_iceberg = 'YES' THEN 'ICEBERG TABLE'
                WHEN table_type = 'BASE TABLE' THEN 'TABLE'
                ELSE table_type
            END AS object_type,
            table_schema,
            table_name
        FROM {{ database }}.information_schema.tables
        WHERE table_schema NOT IN ('INFORMATION_SCHEMA', 'META', 'PUBLIC', 'PUBLIC_META', 'SCHEMACHANGE', 'UNIT_TESTS')
    {% endset %}

    {% set snowflake_schema_results = run_query(get_snowflake_models) %}

    {% for result in snowflake_schema_results %}
        {% set dbt_models = [] %}
        {% set object_Type = result.values()[0] %}
        {% set sql_object_schema = result.values()[1] %}
        {% set sql_object_name = result.values()[2] %}
        {% set sql_object = sql_object_schema ~ "." ~ sql_object_name %}

        {% set matching_nodes = nodes
            | selectattr("schema", "equalto", sql_object_schema | lower)
            | selectattr("name", "equalto", sql_object_name | lower)
        %}
        {% for node in matching_nodes %}
            {% do dbt_models.append(node.schema ~ "." ~ node.name) %}
        {% endfor %}
        {% if dbt_models | length == 0 %}
            {% set matching_nodes = sources
                | selectattr("schema", "equalto", sql_object_schema | lower)
                | selectattr("name", "equalto", sql_object_name | lower)
            %}
            {% for node in matching_nodes %}
                {% do dbt_models.append(node.schema ~ "." ~ node.name) %}
            {% endfor %}
        {% endif %}

        {% if dbt_models | length == 0 %}
            {% if object_Type == "TABLE" %}
                {% do snowflake_tables_to_drop.append(sql_object) %}
            {% elif object_Type == "EXTERNAL TABLE" %}
                {% do snowflake_external_tables_to_drop.append(sql_object) %}
            {% elif object_Type == "DYNAMIC TABLE" %}
                {% do snowflake_dynamic_tables_to_drop.append(sql_object) %}
            {% else %}
                {% do snowflake_views_to_drop.append(sql_object) %}
            {% endif %}
        {% endif %}
    {% endfor %}

    {% do dbt_dataengineers_utils.drop_object("VIEW", database, snowflake_views_to_drop, dry_run) %}
    {% do dbt_dataengineers_utils.drop_object("TABLE", database, snowflake_tables_to_drop, dry_run) %}
    {% do dbt_dataengineers_utils.drop_object("EXTERNAL TABLE", database, snowflake_external_tables_to_drop, dry_run) %}
    {% do dbt_dataengineers_utils.drop_object("DYNAMIC TABLE", database, snowflake_dynamic_tables_to_drop, dry_run) %}
{% endmacro %}
