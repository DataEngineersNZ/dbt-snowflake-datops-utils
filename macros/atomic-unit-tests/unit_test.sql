{% macro unit_test(model, input_mapping, input_parameters, expected_output, test_name, description, compare_columns) %}
    {%if not input_parameters %}
        {% set test_sql = dbt_dataengineers_utils.get_model_unit_test_sql(model, input_mapping, test_name)|trim %}
    {% else %}
        {% set test_sql = dbt_dataengineers_utils.get_object_unit_test_sql(model, input_mapping, input_parameters, test_name)|trim %}
    {% endif %}
    {% do return(dbt_utils.test_equality(expected_output, compare_model=test_sql, compare_columns=compare_columns)) %}
{% endmacro %}


{% test unit_test(model, input_mapping, input_parameters, expected_output, test_name, description, compare_columns) %}
    {% do return(dbt_dataengineers_utils.unit_test(model, input_mapping, input_parameters, expected_output, test_name, description, compare_columns)) %}
{% endtest %}
