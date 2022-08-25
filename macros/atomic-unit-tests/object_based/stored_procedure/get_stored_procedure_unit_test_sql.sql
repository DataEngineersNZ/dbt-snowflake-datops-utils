{% macro get_stored_procedure_unit_test_sql(ns, target_relation, mock_model_relation) %}

    {% do dbt_dataengineers_utils._create_mock_stored_procedure(target_relation, ns) %}
    {% set ns.view_data = "(" ~ dbt_dataengineers_utils.create_return_view(mock_model_relation) ~ ")" %}

    {{ return(ns.view_data) }}
{% endmacro %}

{% macro _create_mock_stored_procedure(target_relation, ns) %}
    {{ return(adapter.dispatch('_create_mock_stored_procedure', 'dbt_dataengineers_utils')(target_relation, ns)) }}
{% endmacro %}

{% macro default___create_mock_stored_procedure(target_relation, ns) %}
    {% do run_query(dbt_dataengineers_utils.snowflake_create_stored_procedure_statement(target_relation, ns)) %}
{% endmacro %}