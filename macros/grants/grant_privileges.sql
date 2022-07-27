{% macro grant_privileges(schemas) %}
    {% if flags.WHICH == 'run' %}
        {%- set domain_schemas = ["SALES", "DM", "CUSTOMER"] -%}
        {% if target.name == 'prod' %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('READERS_PROD') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('ANALYST') }}
            {{ dbt_dataengineers_utils.grant_schema_ownership_access(schemas, 'DATAOPS_ADMIN', false) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access(schemas, 'ANALYST', false) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access(domain_schemas, 'READERS_PROD', false) }}
        {% elif target.name == 'unit-test' %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_schema_ownership_access(schemas, 'DATAOPS_ADMIN', false) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access(schemas, 'DEVELOPERS', false) }}
        {% elif target.name == 'test' %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('READERS_TEST') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('ANALYST') }}
            {{ dbt_dataengineers_utils.grant_schema_ownership_access(schemas, 'DATAOPS_ADMIN', false) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access(schemas, 'ANALYST', false) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access(domain_schemas, 'READERS_TEST', false) }}
        {% elif target.name == 'dev' %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_schema_ownership_access(domain_schemas, 'DEVELOPERS', false) }}
        {% else %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access('DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_schema_ownership_access(schemas, 'DEVELOPERS', false) }}
        {% endif %}
    {% endif %}
{% endmacro %}
