{% macro clean_generic(object_type, database=target.database, dry_run=True) %}
    {% if execute %}
    {% set snowflake_objects_to_drop = [] %}
    {% set nodes = graph.nodes.values() if graph.nodes else [] %}

    {% set get_snowflake_objects %}
         SHOW {{ object_type | upper }}S IN DATABASE {{ database }}
    {% endset %}

    {% set get_snowflake_objects_results = run_query(get_snowflake_objects) %}

    {% for result in get_snowflake_objects_results %}
        {% set dbt_models = [] %}
        {% set sql_object_schema = result['schema_name'] %}
        {% set sql_object_name = result['name'] %}
        {% set sql_object = sql_object_schema ~ "." ~ sql_object_name %}

        {% set target_materialized = object_type | lower | replace(" ", "_") %}
        {% set candidate_nodes = nodes
            | selectattr("schema", "equalto", sql_object_schema | lower)
            | selectattr("name", "equalto", sql_object_name | lower)
        %}
        {% for node in candidate_nodes %}
            {% if node.config.get("materialized") == target_materialized %}
                {% do dbt_models.append(node.schema ~ "." ~ node.name) %}
            {% endif %}
        {% endfor %}

        {% if dbt_models | length == 0 %}
            {% if object_type == "TASK" or object_type == "ALERT" %}
                {% for node in candidate_nodes %}
                    {% if node.config.get("materialized") == "monitorial" %}
                        {% do dbt_models.append(node.schema ~ "." ~ node.name) %}
                    {% endif %}
                {% endfor %}
            {% endif%}
        {% endif %}

        {% if dbt_models | length == 0 %}
            {% do snowflake_objects_to_drop.append(sql_object) %}
        {% endif %}
    {% endfor %}

    {% do dbt_dataengineers_utils.drop_object(object_type, database, snowflake_objects_to_drop, dry_run) %}
    {% endif %}
{% endmacro %}
