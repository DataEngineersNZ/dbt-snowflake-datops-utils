{% macro grant_schema_ownership(exclude_schemas, role_name) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% if execute %}
            {% if "INFORMATION_SCHEMA" not in exclude_schemas %}
                {{ exclude_schemas.append("INFORMATION_SCHEMA") }}
            {% endif %}
            {% set include_schemas = [] %}
            {% set query %}
                show schemas in database {{ target.database }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.name not in exclude_schemas %}
                        {{ include_schemas.append(row.name) }}
                    {% endif %}
                {% endfor %}
                {% if include_schemas | length > 0%}
                    {% for schema in include_schemas %}
                        {% set queries = [] %}
                        {% do log("Verifying Ownership rights on " ~ target.database ~ "." ~ schema ~ " for " ~ role_name, info=True) %}
                        {% set ownership_results = run_query('show grants on schema ' ~ target.database ~ "." ~ schema ~ ' ->> select * from $1 where "privilege" = ' ~ "'OWNERSHIP'" ~ ' and "grantee_name" = ' ~ "'" ~ role_name|upper ~ '";') %}
                        {% if ownership_results | length == 0 %}
                            {% do log("Adding Ownership rights on " ~ target.database ~ "." ~ schema ~ " for " ~ role_name, info=True) %}
                            {{ queries.append(" grant ownership on schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                        {% endif %}
                        {{ queries.extend(get_grant_model_ownership_sql(schema, 'TABLE', role_name)) }}
                        {{ queries.extend(get_grant_model_ownership_sql(schema, 'ICEBERG TABLE', role_name)) }}
                        {{ queries.extend(get_grant_model_ownership_sql(schema, 'DYNAMIC TABLE', role_name)) }}
                        {{ queries.extend(get_grant_model_ownership_sql(schema, 'VIEW', role_name)) }}
                        {{ queries.extend(get_grant_model_ownership_sql(schema, 'MATERIALIZED VIEW', role_name)) }}
                        {{ queries.extend(get_grant_model_ownership_sql(schema, 'EXTERNAL TABLE', role_name)) }}
                        {{ queries.extend(get_grant_model_ownership_sql(schema, 'DYNAMIC TABLE', role_name)) }}
                        {{ queries.extend(get_grant_object_ownership_sql(schema, 'FUNCTION', role_name)) }}
                        {{ queries.extend(get_grant_object_ownership_sql(schema, 'PROCEDURE', role_name)) }}
                        {{ queries.extend(get_grant_object_ownership_sql(schema, 'SEQUENCE', role_name)) }}
                        {{ queries.extend(get_grant_object_ownership_sql(schema, 'STREAM', role_name)) }}
                        {{ queries.extend(get_grant_object_ownership_sql(schema, 'TASK', role_name)) }}
                        {{ queries.extend(get_grant_object_ownership_sql(schema, 'NETWORK RULE', role_name)) }}
                        {{ queries.extend(get_grant_object_ownership_sql(schema, 'STAGE', role_name)) }}
                        {{ queries.extend(get_grant_object_ownership_sql(schema, 'FILE FORMAT', role_name)) }}

                        {% for query in queries %}
                            {% set grant = run_query(query) %}
                        {% endfor %}
                    {% endfor %}
                {% endif %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}

{% macro get_grant_model_ownership_sql(schema_name, object_type, role_name) %}
    {% set query %}
        select distinct
            case
                when is_dynamic = 'YES' then 'DYNAMIC TABLE'
                when is_iceberg = 'YES' then 'ICEBERG TABLE'
                when table_type = 'BASE TABLE' then 'TABLE'
                else tables.table_type
            end as object_type
            , tables.table_schema
            , table_privileges.privilege_type as privilege
            , table_privileges.grantee as grantee_name
        from information_schema.table_privileges
        inner join information_schema.tables
            on table_privileges.table_name = tables.table_name
            and table_privileges.table_schema = tables.table_schema
            and table_privileges.table_catalog = tables.table_catalog
        where tables.table_schema = '{{ schema_name }}'
        and table_privileges.privilege_type in ('OWNERSHIP')
        and table_privileges.grantee = '{{ role_name | upper }}'
        and object_type = '{{ object_type | upper}}'
    {% endset %}
    {% set results = run_query(query) %}
    {% if grant_roles | length == 0 %}
        {% do return([" grant ownership on all " ~ object_type | lower ~ "s in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;"]) %}
    {% else %}
        {% do return([]) %}
    {% endif %}
{% endmacro %}

{% macro get_grant_object_ownership_sql(schema_name, object_type, role_name) %}
    {% set query %}
        select distinct
            privilege,
            granted_on,
            case
                when granted_on = 'PROCEDURE' then replace(split(name, ':')[0], '()', '')
                when granted_on = 'FUNCTION' then replace(split(name, ':')[0], '()', '')
                else name
            end as object_name,
            case
                when granted_on = 'PROCEDURE' then split(name, ':')[1]
                when granted_on = 'FUNCTION' then split(name, ':')[1]
                else ''
            end as arguments,
            grantee_name
        from snowflake.account_usage.grants_to_roles
        where table_schema = '{{ schema_name }}'
        and table_catalog = '{{ role_name | upper }}'
        and privilege = 'OWNERSHIP'
        and granted_on in '{{ object_type }}'
        and grantee_name != '{{ role_name | upper }}'
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if grant_roles | length > 0 %}
        {% for result in results %}
            {% if object_type in ["PROCEDURE", "FUNCTION"] %}
                {{ statements.append(" grant ownership on " ~ object_type | lower  ~ target.database ~ "." ~ schema ~ "." ~ result.object_name ~ "(" ~ result.arguments ~ ")" ~ " to role " ~ role_name ~ " revoke current grants;") }}
            {% else %}
                {{ statements.append(" grant ownership on " ~ object_type | lower  ~ target.database ~ "." ~ schema ~ "." ~ result.object_name ~ " to role " ~ role_name ~ " revoke current grants;") }}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}
