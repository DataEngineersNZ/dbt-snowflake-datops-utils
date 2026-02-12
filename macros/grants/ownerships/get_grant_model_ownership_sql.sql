{% macro get_grant_model_ownership_sql(schema_list, role_name) %}
    {% if flags.WHICH not in ['run','run-operation'] %}
        {% do return([]) %}
    {% endif %}
    {% if not execute %}
        {% do return([]) %}
    {% endif %}
    {% set query %}
        select distinct
            case
                when is_dynamic = 'YES' then 'DYNAMIC TABLE'
                when is_iceberg = 'YES' then 'ICEBERG TABLE'
                when table_type = 'BASE TABLE' then 'TABLE'
                else tables.table_type
            end as object_type
            , tables.table_schema
            , tables.table_name
        from information_schema.table_privileges
        inner join information_schema.tables
            on table_privileges.table_name = tables.table_name
            and table_privileges.table_schema = tables.table_schema
            and table_privileges.table_catalog = tables.table_catalog
        where tables.table_schema in ({{ schema_list }})
          and table_privileges.privilege_type = 'OWNERSHIP'
          and table_privileges.grantee != '{{ role_name | upper }}'
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results and results | length > 0 %}
        {% for r in results %}
            {% do statements.append('grant ownership on ' ~ r[0] ~ ' ' ~ target.database ~ '.' ~ r[1] ~ '.' ~ r[2] ~ ' to role ' ~ role_name ~ ' revoke current grants;') %}
        {% endfor %}
        {% do log('get_grant_model_ownership_sql: generated ' ~ (statements | length) ~ ' statements', info=True) %}
    {% else %}
        {% do log('get_grant_model_ownership_sql: no model ownership changes required', info=True) %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}
