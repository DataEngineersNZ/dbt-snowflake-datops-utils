{% macro get_grant_model_ownership_sql(schema_list, role_name) %}
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
            , table_privileges.privilege_type as privilege
            , table_privileges.grantee as grantee_name
        from information_schema.table_privileges
        inner join information_schema.tables
            on table_privileges.table_name = tables.table_name
            and table_privileges.table_schema = tables.table_schema
            and table_privileges.table_catalog = tables.table_catalog
        where tables.table_schema in ({{ schema_list }})
        and table_privileges.privilege_type = 'OWNERSHIP'
        and table_privileges.grantee != '{{ role_name | upper }}';
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results | length > 0 %}
        {% for result in results %}
            {{ statements.append(" grant ownership on " ~ result.object_type ~ " " ~ target.database ~ "." ~ result.schema_name ~ "." ~ result.table_name ~ " to role " ~ role_name ~ " revoke current grants;") }}
        {% endfor %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}
