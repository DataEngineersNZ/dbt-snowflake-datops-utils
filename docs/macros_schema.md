{% docs ref %}
    This macro is the default dbt macro  for the model. ref is used in the sql file to refer to the model name.

    example:
    
        ref('stg_payments') -- where stg_payments is the ref model name
        or
        ref('stg_payments', true) -- where raw_customers is the source model and true is to include the database name

{% enddocs %}

{% docs src %}
    This macro is the default dbt macro  for the model. source is used in the sql file to refer to the source model name.

    example:

        source('sales', 'raw_customers') -- where raw_customers is the source model and 'sales' is the schema name
        or
        source('sales', 'raw_customers', true) -- where raw_customers is the source model, 'sales' is the schema name and true is to include the database name
    
{% enddocs %}