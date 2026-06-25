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
    {% set include_schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
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

    {% set grant_roles = dbt_dataengineers_utils._grants_normalize_roles(grant_roles) %}
    {% set snowflake_roles = dbt_dataengineers_utils._grants_collect_roles() %}
    {% set execute_statements = [] %}
    {% set schemas_skipped = [0] %}

    {% for schema in schemas %}
        {% do log('====> Processing schema read grants for ' ~ schema, info=True) %}
        {% set schema_statements = [] %}

        {# Get existing schema-level grants once #}
        {% set roles_with_usage = dbt_dataengineers_utils._grants_get_schema_grants(schema, 'USAGE', 'ROLE') %}

        {# Detect which object types exist in the schema #}
        {% set schema_object_types = dbt_dataengineers_utils._grants_get_schema_object_types(schema) %}
        {% do log('====> Schema ' ~ schema ~ ' contains: ' ~ (schema_object_types | join(', ') if schema_object_types | length > 0 else 'no objects'), info=True) %}

        {# Get existing object-level privileges for the grant roles #}
        {% set existing_privs = dbt_dataengineers_utils._grants_get_schema_object_privs(schema, ['SELECT', 'REFERENCES', 'REBUILD', 'READ'], grant_roles) %}

        {# Revoke schema usage from roles not in grant_roles if requested #}
        {% if revoke_current_grants %}
            {% for role_with_usage in roles_with_usage %}
                {% if role_with_usage not in grant_roles and role_with_usage in snowflake_roles %}
                    {% do schema_statements.append('revoke usage on schema ' ~ target.database ~ '.' ~ schema ~ ' from role ' ~ role_with_usage | lower ~ ';') %}
                {% endif %}
            {% endfor %}
        {% endif %}

        {# Revoke object-level read privileges from roles not in grant_roles #}
        {% if revoke_current_grants and grant_roles | length > 0 %}
            {% set revoke_query %}
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
                  and table_privileges.grantee not in ('{{ grant_roles | join("', '") }}')
                  and granted_to = 'ROLE'
            {% endset %}
            {% set tbl_privs = run_query(revoke_query) %}
            {% if tbl_privs %}
                {% for row in tbl_privs %}
                    {% set grantee = row[3] %}
                    {% if grantee in snowflake_roles %}
                        {% do schema_statements.append('revoke ' ~ row[2] | lower ~ ' on all ' ~ row[0] | lower ~ 's in schema ' ~ target.database ~ '.' ~ row[1] | lower ~ ' from role ' ~ grantee | lower ~ ';') %}
                    {% endif %}
                {% endfor %}
            {% endif %}
        {% endif %}

        {# Get future grants once for this schema if needed #}
        {% set future_grants = {} %}
        {% if include_future_grants %}
            {% set future_grants = dbt_dataengineers_utils._grants_get_future_grants(schema) %}
        {% endif %}

        {# Build grant statements — only for object types that exist and privileges not already granted #}
        {% for role in grant_roles %}
            {% set role_future = future_grants.get(role | upper) if future_grants.get(role | upper) is not none else [] %}
            {% set role_privs = existing_privs.get(role | upper) if existing_privs.get(role | upper) is not none else [] %}

            {# Schema USAGE — only grant if not already present #}
            {% if role not in roles_with_usage %}
                {% do schema_statements.append('grant usage on schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}

            {# Object grants — only issue for object types that exist and where the role doesn't already have the privilege #}
            {% if 'VIEW' in schema_object_types and 'SELECT' not in role_privs %}
                {% do schema_statements.append('grant select on all views in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}
            {% if 'MATERIALIZED VIEW' in schema_object_types and 'SELECT' not in role_privs %}
                {% do schema_statements.append('grant select on all materialized views in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}
            {% if 'TABLE' in schema_object_types and 'SELECT' not in role_privs %}
                {% do schema_statements.append('grant select on all tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}
            {% if 'EXTERNAL TABLE' in schema_object_types and 'SELECT' not in role_privs %}
                {% do schema_statements.append('grant select on all external tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}
            {% if 'DYNAMIC TABLE' in schema_object_types and 'SELECT' not in role_privs %}
                {% do schema_statements.append('grant select on all dynamic tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}
            {% if 'STREAM' in schema_object_types and 'SELECT' not in role_privs %}
                {% do schema_statements.append('grant select on all streams in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}
            {% if 'TABLE' in schema_object_types and 'REBUILD' not in role_privs %}
                {% do schema_statements.append('grant rebuild on all tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}
            {% if 'TABLE' in schema_object_types and 'REFERENCES' not in role_privs %}
                {% do schema_statements.append('grant references on all tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}
            {% if 'STAGE' in schema_object_types and 'READ' not in role_privs %}
                {% do schema_statements.append('grant read on all stages in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
            {% endif %}

            {# Future grants - only issue if not already set (these are NOT idempotent — duplicates error) #}
            {% if include_future_grants %}
                {% if 'SELECT:VIEW' not in role_future %}
                    {% do schema_statements.append('grant select on future views in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
                {% endif %}
                {% if 'SELECT:MATERIALIZED VIEW' not in role_future %}
                    {% do schema_statements.append('grant select on future materialized views in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
                {% endif %}
                {% if 'SELECT:TABLE' not in role_future %}
                    {% do schema_statements.append('grant select on future tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
                {% endif %}
                {% if 'REBUILD:TABLE' not in role_future %}
                    {% do schema_statements.append('grant rebuild on future tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
                {% endif %}
                {% if 'REFERENCES:TABLE' not in role_future %}
                    {% do schema_statements.append('grant references on future tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
                {% endif %}
                {% if 'SELECT:EXTERNAL TABLE' not in role_future %}
                    {% do schema_statements.append('grant select on future external tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
                {% endif %}
                {% if 'SELECT:DYNAMIC TABLE' not in role_future %}
                    {% do schema_statements.append('grant select on future dynamic tables in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
                {% endif %}
                {% if 'SELECT:STREAM' not in role_future %}
                    {% do schema_statements.append('grant select on future streams in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
                {% endif %}
            {% endif %}
        {% endfor %}

        {% if schema_statements | length == 0 %}
            {% do log('====> Schema ' ~ schema ~ ': no changes required (skipped)', info=True) %}
            {% do schemas_skipped.append(1) %}
        {% else %}
            {% do execute_statements.extend(schema_statements) %}
        {% endif %}
    {% endfor %}

    {% set total_statements = execute_statements | length %}
    {% if total_statements == 0 %}
        {% do log('grant_schema_read_specific: no changes required across ' ~ (schemas | length) ~ ' schemas', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% do log('grant_schema_read_specific: executing ' ~ total_statements ~ ' statements (' ~ (schemas_skipped | length - 1) ~ '/' ~ (schemas | length) ~ ' schemas skipped, no changes needed)', info=True) %}
    {% for stmt in execute_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}
    {% do log('grant_schema_read_specific: completed read grants', info=True) %}
{% endmacro %}