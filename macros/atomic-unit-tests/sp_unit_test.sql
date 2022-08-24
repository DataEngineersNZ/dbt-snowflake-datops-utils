{% test sp_unit_test(model, input_mapping, input_parameters, expected_output, test_name, description, compare_columns) %}
    {% set test_sql = dbt_dataengineers_utils.get_sp_unit_test_sql(model, input_mapping, input_parameters, test_name)|trim %}
    
    {% do return(dbt_utils.test_equality(expected_output, compare_model=test_sql, compare_columns=compare_columns)) %}
{% endtest %}
