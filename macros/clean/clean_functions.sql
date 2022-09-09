{% macro clean_functions(database=target.database, dry_run=True) %}
    {% set snowflake_functions_to_drop = [] %}
    {% set snowflake_procedures_to_drop = [] %}
    {% set ns = namespace(sql_arguments="") %}
    
    {% set nodes = graph.nodes.values() if graph.nodes else [] %}

    {% set get_snowflake_models %}
        SELECT
            'FUNCTION' AS object_type,
            function_schema AS schema,
            function_name AS name,
            argument_signature AS argument_signature
        FROM {{ database }}.information_schema.functions
        WHERE schema NOT IN ('INFORMATION_SCHEMA', 'META', 'PUBLIC', 'PUBLIC_META', 'SCHEMACHANGE', 'UNIT_TESTS')
        UNION ALL
        SELECT
            'PROCEDURE' AS object_type,
            procedure_schema AS schema,
            procedure_name AS name,
            argument_signature AS argument_signature
        FROM {{ database }}.information_schema.procedures
        WHERE schema NOT IN ('INFORMATION_SCHEMA', 'META', 'PUBLIC', 'PUBLIC_META', 'SCHEMACHANGE', 'UNIT_TESTS')
    {% endset %}

    {% set snowflake_schema_results = run_query(get_snowflake_models) %}

    {% for result in snowflake_schema_results %}
        {% set dbt_models = [] %}
        {% set object_Type = result.values()[0] %}
        {% set sql_object_schema = result.values()[1] %}
        {% set sql_object_name = result.values()[2] %}
        {% set sql_arguments = result.values()[3] | lower | replace("string", "varchar") %}
        {% set sql_signature = (sql_object_schema ~ "." ~sql_object_name ~ sql_arguments) | lower %}
        {% set result_has_matching_nodes = dbt_dataengineers_utils.has_matching_nodes(nodes, "name", sql_object_schema,sql_object_name,sql_arguments) %}

        {% if result_has_matching_nodes == false %}
            {% set result_has_matching_nodes = dbt_dataengineers_utils.has_matching_nodes(nodes, "config.override_name", sql_object_schema,sql_object_name,sql_arguments) %}
            {% if result_has_matching_nodes == false %}

                {% set sql_arguments = sql_arguments  | replace("(", "") | replace(")", "") %}
                {% set sql_arguments_list = sql_arguments.split(',') %}
                {% set new_sql_arguments_list = [] %}
                
                {% for argument in sql_arguments_list %}
                    {% set argument_parts = argument.split(' ') %} 
                    {% do new_sql_arguments_list.append(argument_parts[1]) %}
                {% endfor %}
                {% for argument in new_sql_arguments_list %}
                    {%- if not loop.first %}
                        {% set ns.sql_arguments = ns.sql_arguments ~ "," %}
                    {% else %}
                        {% set ns.sql_arguments = "" %}
                    {% endif -%}
                    {% set ns.sql_arguments = ns.sql_arguments ~ argument %}
                {% endfor %}

                {% set sql_signature = (sql_object_schema ~ "." ~ sql_object_name ~ "(" ~ ns.sql_arguments ~ ")") | lower %}

                {% if result.values()[0] == "PROCEDURE" %}
                    {% do snowflake_procedures_to_drop.append(sql_signature) %}
                {% elif result.values()[0] == "FUNCTION" %}
                    {% do snowflake_functions_to_drop.append(sql_signature) %}
                {% endif %}
            {% endif %}
        {% endif %}
    {% endfor %}

    {% do dbt_dataengineers_utils.drop_object("PROCEDURE", database, snowflake_procedures_to_drop, dry_run) %}
    {% do dbt_dataengineers_utils.drop_object("FUNCTION", database, snowflake_functions_to_drop, dry_run) %}

{% endmacro %}
