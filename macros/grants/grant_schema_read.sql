{% macro grant_schema_read(exclude_schemas, grant_roles, include_future_grants) %}
    {% if flags.WHICH not in ['run', 'run-operation'] %}
        {% do log('Skipping grant_schema_read: not run/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_schema_read: compile phase', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if exclude_schemas is not iterable %}
        {% set exclude_schemas = [] %}
    {% endif %}
    {% if 'INFORMATION_SCHEMA' not in exclude_schemas %}
        {% do exclude_schemas.append('INFORMATION_SCHEMA') %}
    {% endif %}
    {% set include_schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas) %}
    {% if include_schemas | length == 0 %}
        {% do log('grant_schema_read: no schemas to process', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% do log('grant_schema_read: processing ' ~ (include_schemas | length) ~ ' schemas for roles ' ~ (grant_roles | join(', ')), info=True) %}
    {% do dbt_dataengineers_utils.grant_schema_read_specific(include_schemas, grant_roles, include_future_grants, true) %}
{% endmacro %}

{% macro grant_schema_read_specific(schemas, grant_roles, include_future_grants, revoke_current_grants) %}
    {% if flags.WHICH not in ['run', 'run-operation'] %}
        {% do log('Skipping grant_schema_read_specific: not run/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_schema_read_specific: compile phase', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if schemas | length == 0 %}
        {% do log('grant_schema_read_specific: no schemas provided', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set snowflake_roles = dbt_dataengineers_utils._grants_collect_roles() %}
    {% set execute_statements = [] %}
    {% set read_object_types = ['views','materialized views','tables','external tables','dynamic tables','streams'] %}
    {% set revoke_table_privs = ['SELECT','REFERENCES','REBUILD'] %}

    {% for schema in schemas %}
        {% do log('====> Processing schema read grants for ' ~ schema, info=True) %}
        {# Revoke schema usage from roles not in grant_roles if requested #}
        {% set show_query %} show grants on schema {{ target.database }}.{{ schema }}; {% endset %}
        {% set grants_results = run_query(show_query) %}
        {% if grants_results %}
            {% for row in grants_results %}
                {% if row.privilege == 'USAGE' and row.granted_to == 'ROLE' %}
                    {% if row.grantee_name not in grant_roles and revoke_current_grants and row.grantee_name in snowflake_roles %}
                        {{ execute_statements.append('revoke usage on schema ' ~ target.database ~ '.' ~ schema ~ ' from role ' ~ row.grantee_name | lower ~ ';') }}
                    {% endif %}
                {% endif %}
            {% endfor %}
        {% endif %}

        {# Revoke object-level read privileges #}
        {% set priv_query %}
            select distinct
                case
                    when is_dynamic = 'YES' then 'DYNAMIC TABLE'
                    when is_iceberg = 'YES' then 'ICEBERG TABLE'
                    when table_type = 'BASE TABLE' then 'TABLE'
                    else tables.table_type
                end as object_type,
                tables.table_schema,
                table_privileges.privilege_type as privilege,
                table_privileges.grantee as grantee_name
            from information_schema.table_privileges
            inner join information_schema.tables
                on table_privileges.table_name = tables.table_name
                and table_privileges.table_schema = tables.table_schema
                and table_privileges.table_catalog = tables.table_catalog
            where tables.table_schema = '{{ schema }}'
              and table_privileges.privilege_type in ('SELECT','REFERENCES','REBUILD')
        {% endset %}
        {% set tbl_privs = run_query(priv_query) %}
        {% if tbl_privs %}
            {% for row in tbl_privs %}
                {% set obj_type = row[0] %}
                {% set sch = row[1] %}
                {% set priv = row[2] %}
                {% set grantee = row[3] %}
                {% if priv in revoke_table_privs and grantee not in grant_roles and revoke_current_grants and grantee in snowflake_roles %}
                    {{ execute_statements.append('revoke ' ~ priv | lower ~ ' on all ' ~ obj_type | lower ~ 's in schema ' ~ target.database ~ '.' ~ sch | lower ~ ' from role ' ~ grantee | lower ~ ';') }}
                {% endif %}
            {% endfor %}
        {% endif %}

        {# Build grant statements #}
        {% for role in grant_roles %}
            {{ execute_statements.append('grant usage on schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {{ execute_statements.append('grant select on all views in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {{ execute_statements.append('grant select on all materialized views in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {{ execute_statements.append('grant select on all tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {{ execute_statements.append('grant rebuild on all tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {{ execute_statements.append('grant references on all tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {{ execute_statements.append('grant select on all external tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {{ execute_statements.append('grant select on all dynamic tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {{ execute_statements.append('grant select on all streams in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {{ execute_statements.append('grant read on all stages in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {% if include_future_grants %}
                {{ execute_statements.append('grant select on future views in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
                {{ execute_statements.append('grant select on future materialized views in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
                {{ execute_statements.append('grant select on future tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
                {{ execute_statements.append('grant rebuild on future tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
                {{ execute_statements.append('grant references on future tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
                {{ execute_statements.append('grant select on future external tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
                {{ execute_statements.append('grant select on future dynamic tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
                {{ execute_statements.append('grant select on future streams in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') }}
            {% endif %}
        {% endfor %}
    {% endfor %}

    {% set total_statements = execute_statements | length %}
    {% if total_statements == 0 %}
        {% do log('grant_schema_read_specific: no changes required', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% do log('grant_schema_read_specific: executing ' ~ total_statements ~ ' statements across ' ~ (schemas | length) ~ ' schemas', info=True) %}
    {% for stmt in execute_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}
    {% do log('grant_schema_read_specific: completed read grants', info=True) %}
{% endmacro %}