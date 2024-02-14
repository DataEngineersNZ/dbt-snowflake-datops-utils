{% macro grant_privileges(domain_schemas) %}
    {% if flags.WHICH == 'run' %}
        {% if target.name == 'prod' %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_schema_operate_access([], ['OPS_SUPPORT'], false) }}
            {{ dbt_dataengineers_utils.grant_database_usage_access(['READERS_PROD', 'ANALYST']) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access([], ['ANALYST'], false) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access_specific(domain_schemas, ['READERS_PROD'], false, false) }}
            {{ dbt_dataengineers_utils.grant_schema_write_access([], [], false) }}
        {% elif target.name == 'test' %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_schema_operate_access([], ['OPS_SUPPORT'], false) }}
            {{ dbt_dataengineers_utils.grant_database_usage_access(['READERS_TEST', 'ANALYST']) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access([], ['ANALYST'], false) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access_specific(domain_schemas, ['READERS_TEST'], false, false) }}
            {{ dbt_dataengineers_utils.grant_schema_write_access([], [], false) }}
        {% elif target.name == 'unit-test' %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access(['DEVELOPERS']) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access([], ['DEVELOPERS'], false) }}
            {{ dbt_dataengineers_utils.grant_schema_write_access([], [], false) }}
        {% elif target.name == 'dev' %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_schema_operate_access([], ['OPS_SUPPORT'], false) }}
            {{ dbt_dataengineers_utils.grant_database_usage_access([]) }}
            {{ dbt_dataengineers_utils.grant_schema_read_access([], [], false, true) }}
            {{ dbt_dataengineers_utils.grant_schema_write_access([], [], false) }}
        {% else %}
            {{ dbt_dataengineers_utils.grant_database_ownership_access('DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_database_usage_access([]) }}
            {{ dbt_dataengineers_utils.grant_schema_ownership_access([], 'DEVELOPERS') }}
        {% endif %}
    {% endif %}
{% endmacro %}
