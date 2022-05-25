{% docs unit_test_description %}
    describes the atomic unit test that need to be run:

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
    descibes macro should be replacing the source or references in the test

    example:

     ref('dim_customers'): "customers macro name"
     ref('fct_orders'): "prders macro name"

{% enddocs %}

{% docs expected_output %}
    descibes macro should be replacing the source or references in the test

    example:

    ref('tc__customer_has_basic_summary_data__utr__customers'): "expected output"

{% enddocs %}