{% macro drop_views_in_schema_for_snapshots(schema_name, dry_run=False,database=target.database) %}
    {%if execute %}
        {% if flags.WHICH in ('snapshot') %}
            {% set snowflake_views_to_drop = [] %}
            {% set snapshots = graph.nodes.values() if graph.nodes else [] %}
            {% set get_snowflake_models %}
                SELECT
                    CASE
                        WHEN table_type = 'BASE TABLE' THEN 'TABLE'
                        WHEN table_type IS NULL THEN 'DYNAMIC TABLE'
                        ELSE table_type
                    END AS object_type,
                    table_schema,
                    table_name
                FROM {{ database }}.information_schema.tables
                WHERE table_schema = UPPER('{{ schema_name }}')
                AND table_type IN ('VIEW')
            {% endset %}
            {% set snowflake_schema_results = run_query(get_snowflake_models) %}
            {% for result in snowflake_schema_results %}
                {% set dbt_models = [] %}
                {% set object_Type = result.values()[0] %}
                {% set sql_object_schema = result.values()[1] %}
                {% set sql_object_name = result.values()[2] %}

                {% set sql_object = sql_object_schema ~ "." ~ sql_object_name %}
                {% set matching_nodes = snapshots
                     | selectattr("schema", "equalto", sql_object_schema | lower)
                     | selectattr("name", "equalto", sql_object_name | lower)
                     | selectattr("resource_type", "equalto", "snapshot" | lower)
                    %}
                    {% for node in matching_nodes %}
                        {% do snowflake_views_to_drop.append(sql_object) %}
                    {% endfor %}
            {% endfor %}
            {% do dbt_dataengineers_utils.drop_object("VIEW", database, snowflake_views_to_drop, dry_run) %}
        {% endif %}
    {% endif %}
{% endmacro %}