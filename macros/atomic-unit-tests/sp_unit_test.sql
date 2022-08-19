{% test sp_unit_test(model, input_mapping, input_parameters, expected_output, test_name, description, compare_columns) %}
   {% set sp_sql = dbt_dataengineers_utils.get_unit_test_sql(model, input_mapping, input_parameters, test_name)|trim %}

    {%- set target_relation = api.Relation.create( identifier=test_name, schema=schema, database=database) -%}

    {% call statement('main') -%}
        {{ snowflake_create_stored_procedure_statement(target_relation, sql) }}
    {%- endcall %}

    {% set test_sql = "CALL " ~ target_relation.include(database=(not temporary), schema=(not temporary)) ~ "();" %}

    {% do return(dbt_utils.test_equality(expected_output, compare_model=test_sql, compare_columns=compare_columns)) %}
{% endtest %}
