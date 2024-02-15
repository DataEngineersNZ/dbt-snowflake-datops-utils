{% macro grant_privileges(domain_schemas) %}
    {% if flags.WHICH == 'run' %}
        {% if target.name == 'prod' %}
            {{ dbt_dataengineers_utils.grant_database_ownership('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage(['READERS_PROD', 'ANALYST', 'OPS_SUPPORT']) }}
            {{ dbt_dataengineers_utils.grant_schema_ownership([], 'DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_schema_operate([], ['OPS_SUPPORT'], false) }}
            {{ dbt_dataengineers_utils.grant_schema_monitor([], ['OPS_SUPPORT'], false) }}
            {{ dbt_dataengineers_utils.grant_schema_read([], ['ANALYST'], false) }}
            {{ dbt_dataengineers_utils.grant_schema_read_specific(domain_schemas, ['READERS_PROD'], false, false) }}
        {% elif target.name == 'test' %}
            {{ dbt_dataengineers_utils.grant_database_ownership('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage(['READERS_TEST', 'ANALYST', "OPS_SUPPORT"]) }}
            {{ dbt_dataengineers_utils.grant_schema_ownership([], 'DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_schema_operate([], ['OPS_SUPPORT'], false) }}
            {{ dbt_dataengineers_utils.grant_schema_monitor([], ['OPS_SUPPORT'], false) }}
            {{ dbt_dataengineers_utils.grant_schema_read([], ['ANALYST'], false) }}
            {{ dbt_dataengineers_utils.grant_schema_read_specific(domain_schemas, ['READERS_TEST'], false, false) }}
        {% elif target.name == 'unit-test' %}
            {{ dbt_dataengineers_utils.grant_database_ownership('DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_database_usage(['DEVELOPERS']) }}
            {{ dbt_dataengineers_utils.grant_schema_ownership([], 'DATAOPS_ADMIN') }}
            {{ dbt_dataengineers_utils.grant_schema_read([], ['DEVELOPERS'], false) }}
        {% elif target.name == 'dev' %}
            {{ dbt_dataengineers_utils.grant_database_ownership('DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_schema_operate([], ['OPS_SUPPORT'], false) }}
        {% else %}
            {{ dbt_dataengineers_utils.grant_database_ownership('DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_schema_ownership([], 'DEVELOPERS') }}
            {{ dbt_dataengineers_utils.grant_database_usage([]) }}
        {% endif %}
    {% endif %}
{% endmacro %}
