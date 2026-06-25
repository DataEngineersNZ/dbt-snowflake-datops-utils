{% macro grant_schema_monitor(exclude_schemas, grant_roles) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do log('grant_schema_monitor: skip (context)', info=True) %}{% do return(none) %}{% endif %}
    {% set dry_run = var('grants_dry_run', false) %}
    {% if 'INFORMATION_SCHEMA' not in exclude_schemas %}{% do exclude_schemas.append('INFORMATION_SCHEMA') %}{% endif %}
    {% set include_schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
    {% if include_schemas | length == 0 %}{% do log('grant_schema_monitor: no schemas to process', info=True) %}{% do return(none) %}{% endif %}
    {% do log('grant_schema_monitor: processing ' ~ (include_schemas | length) ~ ' schemas for roles: ' ~ (grant_roles | join(', ')), info=True) %}
    {% do dbt_dataengineers_utils.grant_schema_monitor_specific(include_schemas, grant_roles, true, dry_run) %}
{% endmacro %}

{% macro grant_schema_monitor_specific(schemas, grant_roles, revoke_current_grants, dry_run) %}
    {% if flags.WHICH not in ['run'] %}{% do return(none) %}{% endif %}
    {% if schemas | length == 0 or grant_roles | length == 0 %}{% do log('grant_schema_monitor_specific: nothing to do', info=True) %}{% do return(none) %}{% endif %}
    {% set grant_roles = dbt_dataengineers_utils._grants_normalize_roles(grant_roles) %}
    {% set total_revokes = 0 %}
    {% set total_grants = 0 %}
    {% set schemas_skipped = 0 %}
    {% for schema in schemas %}
        {% set schema_statements = [] %}
        {# Query existing MONITOR grants for this schema in one call #}
        {% set existing_monitor_roles = [] %}
        {% set query %}
            select privilege_type, grantee
            from information_schema.object_privileges
            where privilege_type = 'MONITOR' and object_schema = '{{ schema }}'
        {% endset %}
        {% set results = run_query(query) %}
        {% if execute and results %}
            {% for row in results %}
                {% set priv = row[0] %}{% set grantee = row[1] %}
                {% if priv == 'MONITOR' %}
                    {% if grantee not in grant_roles %}
                        {% if revoke_current_grants %}
                            {% do schema_statements.append('revoke monitor on all tasks in schema ' ~ target.database ~ '.' ~ schema ~ ' from role ' ~ grantee ~ ';') %}
                            {% do schema_statements.append('revoke monitor on all pipes in schema ' ~ target.database ~ '.' ~ schema ~ ' from role ' ~ grantee ~ ';') %}
                        {% endif %}
                    {% else %}
                        {% if grantee not in existing_monitor_roles %}
                            {% do existing_monitor_roles.append(grantee) %}
                        {% endif %}
                    {% endif %}
                {% endif %}
            {% endfor %}
        {% endif %}

        {# Check schema USAGE for each role #}
        {% set roles_with_usage = dbt_dataengineers_utils._grants_get_schema_grants(schema, 'USAGE', 'ROLE') %}

        {% for role in grant_roles %}
            {% if role not in existing_monitor_roles %}
                {% if role not in roles_with_usage %}
                    {% do schema_statements.append('grant usage on schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';') %}
                {% endif %}
                {% do schema_statements.append('grant monitor on all pipes in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';') %}
                {% do schema_statements.append('grant monitor on all tasks in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';') %}
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
    {% endfor %}
    {% do log('grant_schema_monitor_specific summary: ' ~ total_grants ~ ' statements executed, ' ~ schemas_skipped ~ '/' ~ (schemas | length) ~ ' schemas skipped (dry_run=' ~ dry_run ~ ')', info=True) %}
{% endmacro %}