{% test unit_test(model, input_mapping, expected_output, name, description,compare_columns) %}
    {% set test_sql = get_unit_test_sql(model, input_mapping, name)|trim %}
    
    {% do return(dbt_utils.test_equality(expected_output, compare_model=test_sql, compare_columns=compare_columns)) %}
{% endtest %}
