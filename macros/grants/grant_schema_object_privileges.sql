{% macro grant_schema_object_privileges(object_type, schema_name, permissions, roles) %}
    {# Grants privileges on all objects of a specific type within a schema. Uses bulk queries to check state. #}
    {% if flags.WHICH not in ['run', 'run-operation'] %}
        {% do log('Skipping grant_schema_object_privileges: not run/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_schema_object_privileges: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {# Convert string parameters to lists #}
    {% if permissions is string %}
        {% set permission_list = permissions.split(',') | map('trim') | list %}
    {% else %}
        {% set permission_list = permissions %}
    {% endif %}

    {% if roles is string %}
        {% set role_list = roles.split(',') | map('trim') | map('upper') | list %}
    {% else %}
        {% set role_list = dbt_dataengineers_utils._grants_normalize_roles(roles) %}
    {% endif %}

    {% do log('grant_schema_object_privileges: processing ' ~ object_type ~ ' objects in schema ' ~ schema_name, info=True) %}
    {% do log('====> Target permissions: ' ~ (permission_list | join(', ')), info=True) %}
    {% do log('====> Target roles: ' ~ (role_list | join(', ')), info=True) %}

    {# Discover objects #}
    {% set discovered_objects = [] %}
    {% if object_type.upper() in ['FUNCTION', 'PROCEDURE'] %}
        {% if object_type.upper() == 'FUNCTION' %}
            {% do discovered_objects.extend(dbt_dataengineers_utils.get_functions("'" ~ schema_name ~ "'")) %}
        {% elif object_type.upper() == 'PROCEDURE' %}
            {% do discovered_objects.extend(dbt_dataengineers_utils.get_procedures("'" ~ schema_name ~ "'")) %}
        {% endif %}
    {% else %}
        {% set objects_query %}
                show {{ object_type }}s in schema {{ target.database }}.{{ schema_name }};
        {% endset %}
        {% set objects_results = run_query(objects_query) %}
        {% if objects_results %}
            {% for row in objects_results %}
                {% set object_name = target.database ~ '.' ~ schema_name ~ '.' ~ row[1] %}
                {% do discovered_objects.append(object_name) %}
            {% endfor %}
        {% endif %}
    {% endif %}

    {% if discovered_objects | length == 0 %}
        {% do log('grant_schema_object_privileges: no ' ~ object_type ~ ' objects found in schema ' ~ schema_name, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('====> Found ' ~ (discovered_objects | length) ~ ' ' ~ object_type ~ 's', info=True) %}

    {# Bulk query: get all existing privileges for this object type in this schema #}
    {% set existing_privs = dbt_dataengineers_utils._grants_get_schema_object_privs(schema_name, permission_list, role_list) %}

    {# Check which roles need grants #}
    {% set bulk_grant_needed = {} %}
    {% for role in role_list %}
        {% set role_privs = existing_privs.get(role) if existing_privs.get(role) is not none else [] %}
        {% for privilege in permission_list %}
            {% if privilege not in role_privs %}
                {% if bulk_grant_needed.get(role) is none %}
                    {% set _ = bulk_grant_needed.update({role: []}) %}
                {% endif %}
                {% if privilege not in bulk_grant_needed.get(role) %}
                    {% do bulk_grant_needed.get(role).append(privilege) %}
                {% endif %}
            {% endif %}
        {% endfor %}
    {% endfor %}

    {# Build revoke statements for roles NOT in the list that have these privs #}
    {% set revoke_statements = [] %}
    {% set revoke_query %}
        select distinct privilege_type, grantee
        from information_schema.object_privileges
        where object_schema = '{{ schema_name }}'
          and privilege_type in ({{ permission_list | map('tojson') | join(', ') }})
          and grantee not in ({{ role_list | map('tojson') | join(', ') }})
          and grantor is not null
    {% endset %}
    {% set revoke_results = run_query(revoke_query) %}
    {% if execute and revoke_results %}
        {% for row in revoke_results %}
            {% set stmt = 'revoke ' ~ row[0] | lower ~ ' on all ' ~ object_type | lower ~ 's in schema ' ~ target.database ~ '.' ~ schema_name ~ ' from role ' ~ row[1] | lower ~ ';' %}
            {% if stmt not in revoke_statements %}
                {% do revoke_statements.append(stmt) %}
            {% endif %}
        {% endfor %}
    {% endif %}

    {# Build bulk grant statements #}
    {% set bulk_grant_statements = [] %}
    {% for role in bulk_grant_needed.keys() %}
        {% for privilege in bulk_grant_needed.get(role) %}
            {% set bulk_stmt = 'grant ' ~ privilege | lower ~ ' on all ' ~ object_type | lower ~ 's in schema ' ~ target.database ~ '.' ~ schema_name ~ ' to role ' ~ role | lower ~ ';' %}
            {% do bulk_grant_statements.append(bulk_stmt) %}
        {% endfor %}
    {% endfor %}

    {% set all_statements = revoke_statements + bulk_grant_statements %}

    {% if all_statements | length == 0 %}
        {% do log('grant_schema_object_privileges: no changes required for ' ~ object_type ~ ' objects in schema ' ~ schema_name, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('grant_schema_object_privileges summary: ' ~ (revoke_statements | length) ~ ' revokes, ' ~ (bulk_grant_statements | length) ~ ' bulk grants for ' ~ object_type ~ ' objects in schema ' ~ schema_name, info=True) %}

    {# Execute statements #}
    {% if var('grants_dry_run', false) %}
        {% do log('DRY RUN MODE - statements would be:', info=True) %}
        {% for stmt in all_statements %}
            {% do log(stmt, info=True) %}
        {% endfor %}
    {% else %}
        {% for stmt in all_statements %}
            {% do log(stmt, info=True) %}
            {% set _ = run_query(stmt) %}
        {% endfor %}
    {% endif %}

    {% do log('grant_schema_object_privileges: completed privilege reconciliation for ' ~ object_type ~ ' objects in schema ' ~ schema_name, info=True) %}
{% endmacro %}