{% macro get_user_defined_function_unit_test_sql(ns, target_relation, mock_model_relation) %}

    {% set ns.sdk_version = ns.graph_model.config.get("sdk_version") %}
    {% set ns.import_Path = ns.graph_model.config.get("import_Path") %}
    {% set ns.packages = ns.graph_model.config.get("packages") %}
    {% set ns.handler_name = ns.graph_model.config.get("handler_name") %}
    {% set ns.imports = ns.graph_model.config.get("imports") %}
    {% set ns.target_path = ns.graph_model.config.get("target_path") %}
    {% set ns.runtime_version = ns.graph_model.config.get("runtime_version") %}
    
    {% do dbt_dataengineers_utils._create_mock_user_defined_function(target_relation, ns) %}    
    {% if ns.return_type.startswith("table") %}
        {% set ns.view_data = "( SELECT * FROM table(" ~ mock_model_relation ~ "()))" %}
    {% else %}
        {% set ns.view_data = "( SELECT " ~ mock_model_relation ~ "() AS result)" %}
    {% endif %}
    {{ return(ns.view_data) }}
{% endmacro %}

{% macro _create_mock_user_defined_function(target_relation, ns) %}
    {{ return(adapter.dispatch('_create_mock_user_defined_function', 'dbt_dataengineers_utils')(target_relation, ns)) }}
{% endmacro %}

{% macro default___create_mock_user_defined_function(target_relation, ns) %}
    {% do run_query(dbt_dataengineers_utils.snowflake_create_user_defined_functions_statement(target_relation, ns)) %}
{% endmacro %}
