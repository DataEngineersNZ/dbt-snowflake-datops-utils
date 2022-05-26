{% docs ref %}
    This macro overrides the default 'ref' dbt macro when in your local dbt project. This is used in your models to reference other models.

    example:
    
        ref('stg_payments') -- where stg_payments is the ref model name
        or
        ref('stg_payments', true) -- where raw_customers is the source model and true is to include the database name

{% enddocs %}

{% docs src %}
    This macro overrides the default 'source' dbt macro when in your local dbt project. This is used in your models to reference source models.

    example:

        source('sales', 'raw_customers') -- where raw_customers is the source model and 'sales' is the schema name
        or
        source('sales', 'raw_customers', true) -- where raw_customers is the source model, 'sales' is the schema name and true is to include the database name

{% enddocs %}
