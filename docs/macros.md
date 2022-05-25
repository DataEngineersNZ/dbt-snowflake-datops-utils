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

{% docs date_masking_policy %}
    This macro creates the masking policy as per roles. Masking policy is written in the <<schema>>.yml file. 

    example: for stg_customers


    version: 2
    models:
    - name: stg_customers
        columns:
        - name: date_of_birth
            description: Customer's date of birth. PII.
            meta:
              masking_policy: date_mask

{% enddocs %}

{% docs number_masking_policy %}
    This macro creates the masking policy as per roles. Masking policy is written in the <<schema>>.yml file. 

    example: for stg_customers

    version: 2
    models:
    - name: stg_customers
        columns:
        - name: customer_id
            description: This is a unique identifier for a customer
            meta:
              masking_policy: number_mask

{% enddocs %}

{% docs string_masking_policy %}
    This macro creates the masking policy as per roles. Masking policy is written in the <<schema>>.yml file. 

    example: for stg_customers

    version: 2
    models:
    - name: stg_customers
        columns:
        - name: first_name
            description: Customer's first name. PII.
            meta:
              masking_policy: string_mask

{% enddocs %}

{% docs ref %}
    This macro is the default dbt macro  for the model. ref is used in the sql file to refer to the model name. example:

    example:
    
        ref('stg_payments') -- where stg_payments is the ref model name
        or
        ref('stg_payments', true) -- where raw_customers is the source model and true is to include the database name

{% enddocs %}

{% docs src %}
    This macro is the default dbt macro  for the model. source is used in the sql file to refer to the source model name. example:

    example:

        source('sales', 'raw_customers') -- where raw_customers is the source model and 'sales' is the schema name
        or
        source('sales', 'raw_customers', true) -- where raw_customers is the source model, 'sales' is the schema name and true is to include the database name
    
{% enddocs %}
