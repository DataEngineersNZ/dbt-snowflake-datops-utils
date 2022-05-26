{% docs unit_test_description %}
    This macro describes an atomic unit test that is executed when running 'dbt test'.

    example:

        models:
        - name: customers
            description: This table has basic information about a customer, as well as some derived facts based on a customer's orders
            tests:
            - unit_test:
                name: "tc__customer_has_basic_summary_data"
                description: "Ensures all data is present for the customer record"
                input_mapping:
                    ref('dim_customers'): "macro_name"
                expected_output: ref('tc__customer_has_basic_summary_data__utr__customers')
            columns:
            - name: customer_id
                description: This is a unique identifier for a customer
                tests:
                - unique
                - not_null

{% enddocs %}

{% docs input_mapping_description %}
    Specifies which 'ref' or 'source' macros should be replaced with the relevant test macro

    example:

     ref('dim_customers'): "customers macro name"
     ref('fct_orders'): "prders macro name"

{% enddocs %}

{% docs expected_output %}
    Specifies the expected output of the model. This needs to be a table and not a macro.

    example:

    ref('tc__customer_has_basic_summary_data__utr__customers'): "expected output"

{% enddocs %}
