{% macro grant_schema_monitor(exclude_schemas, grant_roles) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do log('grant_schema_monitor: skip (context)', info=True) %}{% do return(none) %}{% endif %}
    {% set dry_run = var('grants_dry_run', false) %}
    {% if 'INFORMATION_SCHEMA' not in exclude_schemas %}{% do exclude_schemas.append('INFORMATION_SCHEMA') %}{% endif %}
    {% set include_schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas) %}
    {% if include_schemas | length == 0 %}{% do log('grant_schema_monitor: no schemas to process', info=True) %}{% do return(none) %}{% endif %}
    {% do log('grant_schema_monitor: processing ' ~ (include_schemas | length) ~ ' schemas for roles: ' ~ (grant_roles | join(', ')), info=True) %}
    {% do dbt_dataengineers_utils.grant_schema_monitor_specific(include_schemas, grant_roles, true, dry_run) %}
{% endmacro %}

{% macro grant_schema_monitor_specific(schemas, grant_roles, revoke_current_grants, dry_run) %}
    {% if flags.WHICH not in ['run'] %}{% do return(none) %}{% endif %}
    {% if schemas | length == 0 or grant_roles | length == 0 %}{% do log('grant_schema_monitor_specific: nothing to do', info=True) %}{% do return(none) %}{% endif %}
    {% set total_revokes = 0 %}
    {% set total_grants = 0 %}
    {% for schema in schemas %}
        {% set existing_roles = [] %}
        {% set query %}
            select object_type, concat(object_schema, '.', object_name) as object_name, privilege_type, grantee
            from information_schema.object_privileges
            where privilege_type = 'MONITOR' and object_schema = '{{ schema }}'
        {% endset %}
        {% set results = run_query(query) %}
        {% if execute and results %}
            {% for row in results %}
                {% set priv = row[2] %}{% set grantee = row[3] %}
                {% if priv == 'MONITOR' %}
                    {% if grantee not in grant_roles %}
                        {% if revoke_current_grants %}
                            {% set stmt = 'revoke monitor on ' ~ row[0] ~ ' in schema ' ~ target.database ~ '.' ~ row[1] ~ ' from role ' ~ grantee ~ ';' %}
                            {% do log(stmt, info=True) %}
                            {% if not dry_run %}{% set _ = run_query(stmt) %}{% endif %}
                            {% set total_revokes = total_revokes + 1 %}
                        {% endif %}
                    {% else %}
                        {% do existing_roles.append(grantee) %}
                    {% endif %}
                {% endif %}
            {% endfor %}
        {% endif %}
        {% for role in grant_roles %}
            {% if role not in existing_roles %}
                {% set stmts = [
                    'grant usage on schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';',
                    'grant monitor on all pipes in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';',
                    'grant monitor on all tasks in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';'
                ] %}
                {% for s in stmts %}
                    {% do log(s, info=True) %}
                    {% if not dry_run %}{% set _ = run_query(s) %}{% endif %}
                    {% set total_grants = total_grants + 1 %}
                {% endfor %}
            {% endif %}
        {% endfor %}
    {% endfor %}
    {% do log('grant_schema_monitor_specific summary: ' ~ total_revokes ~ ' revokes, ' ~ total_grants ~ ' grants (dry_run=' ~ dry_run ~ ')', info=True) %}
{% endmacro %}