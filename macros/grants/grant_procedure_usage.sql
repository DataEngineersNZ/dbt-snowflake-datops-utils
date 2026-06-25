{% macro grant_schema_procedure_usage(exclude_schemas, grant_roles) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do log('grant_schema_procedure_usage: skip (context)', info=True) %}{% do return(none) %}{% endif %}
    {% set dry_run = var('grants_dry_run', false) %}
    {% if 'INFORMATION_SCHEMA' not in exclude_schemas %}{% do exclude_schemas.append('INFORMATION_SCHEMA') %}{% endif %}
    {% set include_schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
    {% if include_schemas | length == 0 %}{% do log('grant_schema_procedure_usage: no schemas to process', info=True) %}{% do return(none) %}{% endif %}
    {% do log('grant_schema_procedure_usage: processing ' ~ (include_schemas | length) ~ ' schemas for roles: ' ~ (grant_roles | join(', ')), info=True) %}
    {% do dbt_dataengineers_utils.grant_schema_procedure_usage_specific(include_schemas, grant_roles, true, dry_run) %}
{% endmacro %}

{% macro grant_schema_procedure_usage_specific(schemas, grant_roles, revoke_current_grants, dry_run) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return(none) %}{% endif %}
    {% if schemas | length == 0 or grant_roles | length == 0 %}{% do log('grant_schema_procedure_usage_specific: nothing to do', info=True) %}{% do return(none) %}{% endif %}
    {% set grant_roles = dbt_dataengineers_utils._grants_normalize_roles(grant_roles) %}
    {% set total_grants = 0 %}
    {% set schemas_skipped = 0 %}
    {% for schema in schemas %}
        {% set schema_statements = [] %}

        {# Check if there are any procedures in this schema #}
        {% set proc_query %}
            select count(*) as cnt
            from information_schema.procedures
            where procedure_schema = '{{ schema }}'
        {% endset %}
        {% set proc_count_result = run_query(proc_query) %}
        {% set proc_count = proc_count_result[0][0] if (execute and proc_count_result) else 0 %}

        {% if proc_count == 0 %}
            {% do log('grant_schema_procedure_usage_specific: no procedures found in schema ' ~ schema, info=True) %}
        {% else %}
            {% do log('grant_schema_procedure_usage_specific: found ' ~ proc_count ~ ' procedures in schema ' ~ schema, info=True) %}

            {# Get existing USAGE grants on procedures in this schema in one query #}
            {% set existing_usage_roles = [] %}
            {% set usage_query %}
                select distinct grantee
                from information_schema.object_privileges
                where object_schema = '{{ schema }}'
                  and privilege_type = 'USAGE'
                  and object_type = 'PROCEDURE'
            {% endset %}
            {% set usage_results = run_query(usage_query) %}
            {% if execute and usage_results %}
                {% for row in usage_results %}
                    {% if row[0] not in existing_usage_roles %}
                        {% do existing_usage_roles.append(row[0]) %}
                    {% endif %}
                {% endfor %}
            {% endif %}

            {# Revoke from roles not in grant_roles that currently have USAGE #}
            {% if revoke_current_grants %}
                {% for role_with_usage in existing_usage_roles %}
                    {% if role_with_usage not in grant_roles %}
                        {% do schema_statements.append('revoke usage on all procedures in schema ' ~ target.database ~ '.' ~ schema ~ ' from role ' ~ role_with_usage ~ ';') %}
                    {% endif %}
                {% endfor %}
            {% endif %}

            {# Check schema USAGE #}
            {% set roles_with_usage = dbt_dataengineers_utils._grants_get_schema_grants(schema, 'USAGE', 'ROLE') %}

            {# Grant procedure usage only to roles that don't already have it #}
            {% for role in grant_roles %}
                {% if role not in existing_usage_roles %}
                    {% if role not in roles_with_usage %}
                        {% do schema_statements.append('grant usage on schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';') %}
                    {% endif %}
                    {% do schema_statements.append('grant usage on all procedures in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';') %}
                {% endif %}
            {% endfor %}
        {% endif %}

        {% if schema_statements | length == 0 %}
            {% set schemas_skipped = schemas_skipped + 1 %}
        {% else %}
            {% for s in schema_statements %}
                {% do log(s, info=True) %}
                {% if not dry_run %}{% set _ = run_query(s) %}{% endif %}
            {% endfor %}
            {% set total_grants = total_grants + schema_statements | length %}
        {% endif %}
    {% endfor %}
    {% do log('grant_schema_procedure_usage_specific summary: ' ~ total_grants ~ ' statements executed, ' ~ schemas_skipped ~ '/' ~ (schemas | length) ~ ' schemas skipped (dry_run=' ~ dry_run ~ ')', info=True) %}
{% endmacro %}
