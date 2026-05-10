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

                {# Strip the outer parentheses from the Snowflake argument signature #}
                {% set sql_arguments = sql_arguments | replace("(", "", 1) %}
                {% if sql_arguments.endswith(")") %}
                    {% set sql_arguments = sql_arguments[:-1] %}
                {% endif %}
                {% set sql_arguments = sql_arguments | trim %}

                {# Extract type-only tokens using paren-aware split #}
                {% set new_sql_arguments_list = [] %}
                {% if sql_arguments | length > 0 %}
                    {% for param in dbt_dataengineers_utils.split_params(sql_arguments) %}
                        {% set param_type = dbt_dataengineers_utils.extract_param_type(param) %}
                        {% if param_type | length > 0 %}
                            {% do new_sql_arguments_list.append(param_type) %}
                        {% endif %}
                    {% endfor %}
                {% endif %}
                {% set ns.sql_arguments = new_sql_arguments_list | join(",") %}

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
