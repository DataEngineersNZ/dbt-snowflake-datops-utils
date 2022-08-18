{% test unit_test(model, input_mapping, expected_output, test_name, description, compare_columns) %}
    {% set test_sql = dbt_dataengineers_utils.get_unit_test_sql(model, input_mapping, none, test_name)|trim %}
    
    {% do return(dbt_utils.test_equality(expected_output, compare_model=test_sql, compare_columns=compare_columns)) %}
{% endtest %}
