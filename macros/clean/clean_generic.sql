{% macro clean_generic(object_type, database=target.database, dry_run=True) %}
    {% set snowflake_streams_to_drop = [] %}
    {% set nodes = graph.nodes.values() if graph.nodes else [] %}
    {% set schema_index = 3 %}

    {% set get_snowflake_steams %}
         SHOW {{ object_type | upper }}S IN DATABASE {{ database }}
    {% endset %}

    {% set snowflake_stream_results = run_query(get_snowflake_steams) %}
    {% if object_type == "TASK" %}
        {% set schema_index = 4 %}
    {% endif %}

    {% for result in snowflake_stream_results %}
        {% set dbt_models = [] %}
        {% set sql_object_schema = result.values()[schema_index] %}
        {% set sql_object_name = result.values()[1] %}
        {% set sql_object = sql_object_schema ~ "." ~ sql_object_name %}

        {% set matching_nodes = nodes
            | selectattr("schema", "equalto", sql_object_schema | lower)
            | selectattr("name", "equalto", sql_object_name | lower)
            | selectattr("config.materialized", "equalto", object_type | lower)
        %}
        {% for node in matching_nodes %}
            {% do dbt_models.append(node.schema ~ "." ~ node.name) %}
        {% endfor %}

        {% if dbt_models | length == 0 %}
            {% do snowflake_streams_to_drop.append(sql_object) %}
        {% endif %}
    {% endfor %}

    {% do dbt_dataengineers_utils.drop_object(object_type, database, snowflake_streams_to_drop, dry_run) %}
{% endmacro %}
