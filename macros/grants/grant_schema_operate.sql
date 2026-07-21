{% macro grant_schema_operate(exclude_schemas, grant_roles) %}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}{% do log('grant_schema_operate: skip (context)', info=True) %}{% do return(none) %}{% endif %}
    {% set dry_run = var('grants_dry_run', false) %}
    {% if 'INFORMATION_SCHEMA' not in exclude_schemas %}{% do exclude_schemas.append('INFORMATION_SCHEMA') %}{% endif %}
    {% set include_schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
    {% if include_schemas | length == 0 %}{% do log('grant_schema_operate: no schemas to process', info=True) %}{% do return(none) %}{% endif %}
    {% do log('grant_schema_operate: processing ' ~ (include_schemas | length) ~ ' schemas for roles: ' ~ (grant_roles | join(', ')), info=True) %}
    {% do dbt_dataengineers_utils.grant_schema_operate_specific(include_schemas, grant_roles, true, dry_run) %}
{% endmacro %}

{% macro grant_schema_operate_specific(schemas, grant_roles, revoke_current_grants, dry_run) %}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}{% do return(none) %}{% endif %}
    {% if schemas | length == 0 or grant_roles | length == 0 %}{% do log('grant_schema_operate_specific: nothing to do', info=True) %}{% do return(none) %}{% endif %}
    {% set grant_roles = dbt_dataengineers_utils._grants_normalize_roles(grant_roles) %}
    {% set total_grants = 0 %}
    {% set schemas_skipped = 0 %}

    {# Bulk detect object types for all schemas in 2 queries #}
    {% set all_schema_object_types = dbt_dataengineers_utils._grants_get_all_schema_object_types() %}

    {% for schema in schemas %}
        {% set schema_statements = [] %}

        {# Look up object types from bulk query result #}
        {% set schema_object_types = all_schema_object_types.get(schema, []) %}
        {% set has_pipes = 'PIPE' in schema_object_types %}
        {% set has_tasks = 'TASK' in schema_object_types %}

        {# Skip schema entirely if no pipes or tasks #}
        {% if not has_pipes and not has_tasks %}
            {% do log('====> Schema ' ~ schema ~ ': no pipes or tasks, skipping operate grants', info=True) %}
            {% set schemas_skipped = schemas_skipped + 1 %}
        {% else %}
            {# Count total pipes and tasks in this schema #}
            {% set object_count_query %}
                select object_type, count(distinct object_name) as cnt
                from information_schema.object_privileges
                where object_schema = '{{ schema }}'
                  and object_type in ('PIPE', 'TASK')
                  and grantor is not null
                group by object_type
            {% endset %}
            {% set object_counts = {} %}
            {% set oc_results = run_query(object_count_query) %}
            {% if execute and oc_results %}
                {% for row in oc_results %}
                    {% set _ = object_counts.update({row[0]: row[1]}) %}
                {% endfor %}
            {% endif %}
            {% set total_operate_objects = (object_counts.get('PIPE', 0) | int) + (object_counts.get('TASK', 0) | int) %}

            {# Query existing OPERATE grants per role for this schema #}
            {% set existing_operate_roles = [] %}
            {% set fully_granted_roles = [] %}
            {% set query %}
                select grantee, count(distinct object_name) as granted_count
                from information_schema.object_privileges
                where privilege_type = 'OPERATE' and object_schema = '{{ schema }}'
                  and object_type in ('PIPE', 'TASK')
                group by grantee
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute and results %}
                {% for row in results %}
                    {% set grantee = row[0] %}
                    {% if grantee not in existing_operate_roles %}
                        {% do existing_operate_roles.append(grantee) %}
                    {% endif %}
                    {% if grantee in grant_roles and row[1] >= total_operate_objects %}
                        {% do fully_granted_roles.append(grantee) %}
                    {% endif %}
                {% endfor %}
            {% endif %}

            {# Revoke from roles not in grant_roles that currently have OPERATE #}
            {% if revoke_current_grants %}
                {% for role_with_operate in existing_operate_roles %}
                    {% if role_with_operate not in grant_roles %}
                        {% if has_tasks %}
                            {% do schema_statements.append('revoke operate on all tasks in schema ' ~ target.database ~ '.' ~ schema ~ ' from role ' ~ role_with_operate ~ ';') %}
                        {% endif %}
                        {% if has_pipes %}
                            {% do schema_statements.append('revoke operate on all pipes in schema ' ~ target.database ~ '.' ~ schema ~ ' from role ' ~ role_with_operate ~ ';') %}
                        {% endif %}
                    {% endif %}
                {% endfor %}
            {% endif %}

            {# Check schema USAGE for each role #}
            {% set roles_with_usage = dbt_dataengineers_utils._grants_get_schema_grants(schema, 'USAGE', 'ROLE') %}

            {# Grant operate only to roles that don't already cover all objects #}
            {% for role in grant_roles %}
                {% if role not in fully_granted_roles %}
                    {% if role not in roles_with_usage %}
                        {% do schema_statements.append('grant usage on schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';') %}
                    {% endif %}
                    {% if has_pipes %}
                        {% do schema_statements.append('grant operate on all pipes in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';') %}
                    {% endif %}
                    {% if has_tasks %}
                        {% do schema_statements.append('grant operate on all tasks in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';') %}
                    {% endif %}
                {% endif %}
            {% endfor %}

            {% if schema_statements | length == 0 %}
                {% set schemas_skipped = schemas_skipped + 1 %}
            {% else %}
                {% for s in schema_statements %}
                    {% do log(s, info=True) %}
                    {% if not dry_run %}{% set _ = run_query(s) %}{% endif %}
                {% endfor %}
                {% set total_grants = total_grants + schema_statements | length %}
            {% endif %}
        {% endif %}
    {% endfor %}
    {% do log('grant_schema_operate_specific summary: ' ~ total_grants ~ ' statements executed, ' ~ schemas_skipped ~ '/' ~ (schemas | length) ~ ' schemas skipped (dry_run=' ~ dry_run ~ ')', info=True) %}
{% endmacro %}