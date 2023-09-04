{% macro target_warehouse_environment() %}
{% set snowflake_warehouse = "DEV_WH" if target.name == "local-dev" else "DATAOPS_WH" %}
{{ return(snowflake_warehouse) }}
{% endmacro %}