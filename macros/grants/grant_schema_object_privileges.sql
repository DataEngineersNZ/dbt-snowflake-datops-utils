{% macro grant_schema_object_privileges(object_type, schema_name, permissions, roles) %}
    {# Enhanced macro that grants privileges on all objects of a specific type within a schema #}
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
        {% set role_list = roles.split(',') | map('trim') | list %}
    {% else %}
        {% set role_list = roles %}
    {% endif %}

    {% do log('grant_schema_object_privileges: processing ' ~ object_type ~ ' objects in schema ' ~ schema_name, info=True) %}
    {% do log('====> Target permissions: ' ~ (permission_list | join(', ')), info=True) %}
    {% do log('====> Target roles: ' ~ (role_list | join(', ')), info=True) %}

    {# Discover objects of the specified type in the schema #}
    {% set objects_query %}
        show {{ object_type }}s in schema {{ target.database }}.{{ schema_name }};
    {% endset %}

    {% set objects_results = run_query(objects_query) %}
    {% set discovered_objects = [] %}

    {% if objects_results %}
        {% for row in objects_results %}
            {% if object_type.upper() in ['TABLE', 'VIEW'] %}
                {% set object_name = schema_name ~ '.' ~ row[1] %}  {# name column is usually second #}
            {% elif object_type.upper() in ['FUNCTION', 'PROCEDURE'] %}
                {% set object_name = schema_name ~ '.' ~ row[1] ~ row[10] %}  {# name + arguments #}
            {% else %}
                {% set object_name = schema_name ~ '.' ~ row[1] %}  {# default to name column #}
            {% endif %}
            {% do discovered_objects.append(object_name) %}
        {% endfor %}
    {% endif %}

    {% if discovered_objects | length == 0 %}
        {% do log('grant_schema_object_privileges: no ' ~ object_type ~ ' objects found in schema ' ~ schema_name, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('====> Found ' ~ (discovered_objects | length) ~ ' ' ~ object_type ~ ' objects: ' ~ (discovered_objects | join(', ')), info=True) %}

    {# Enhanced logic with bulk grants and individual revokes #}
    {% set excluded_privs = ['OWNERSHIP'] %} {# Always ignore these for grant/revoke logic #}
    {% set revokable_read_privs = ['SELECT','REFERENCES','REBUILD'] %}
    {% set revoke_statements = [] %}
    {% set bulk_grant_needed = {} %} {# Track role->privilege combinations that need bulk grants #}
    {% set all_existing_role_privs = {} %} {# Global tracking of existing privileges across all objects #}

    {# First pass: analyze existing grants and determine revokes #}
    {% for object in discovered_objects %}
        {% set existing_role_priv_map = {} %} {# key role -> list of privs for this object #}
        {% do log('====> Processing ' ~ object_type ~ ' ' ~ object ~ ' with desired privileges ' ~ (permission_list | join(', ')) ~ ' for roles ' ~ (role_list | join(', ')), info=True) %}

        {% set query %}
            show grants on {{ object_type }} {{ target.database }}.{{ object }};
        {% endset %}
        {% set results = run_query(query) %}

        {% if results %}
            {% for row in results %}
                {% if row.privilege not in excluded_privs %}
                    {# classify existing privilege #}
                    {% set _role = row.grantee_name %}
                    {% set _priv = row.privilege %}

                    {# Track existing privileges globally #}
                    {% if all_existing_role_privs.get(_role) is none %}
                        {% set _ = all_existing_role_privs.update({_role: {}}) %}
                    {% endif %}
                    {% if all_existing_role_privs.get(_role).get(_priv) is none %}
                        {% set _ = all_existing_role_privs.get(_role).update({_priv: []}) %}
                    {% endif %}
                    {% do all_existing_role_privs.get(_role).get(_priv).append(object) %}

                    {% if _priv in permission_list %}
                        {% if _role not in role_list %}
                            {# Revoke privilege from unwanted roles #}
                            {% do revoke_statements.append('revoke ' ~ _priv | lower ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' from role ' ~ _role | lower ~ ';') %}
                        {% else %}
                            {# Track existing desired priv for this object #}
                            {% if existing_role_priv_map.get(_role) is none %}
                                {% set _ = existing_role_priv_map.update({_role: []}) %}
                            {% endif %}
                            {% if _priv not in existing_role_priv_map.get(_role) %}
                                {% set __ = existing_role_priv_map.get(_role).append(_priv) %}
                            {% endif %}
                        {% endif %}
                    {% else %}
                        {# privilege not desired -> revoke if granted to managed roles #}
                        {% if _role in role_list or _priv in revokable_read_privs %}
                            {% do revoke_statements.append('revoke ' ~ _priv | lower ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' from role ' ~ _role | lower ~ ';') %}
                        {% endif %}
                    {% endif %}
                {% endif %}
            {% endfor %}
        {% endif %}

        {# Track what bulk grants are needed #}
        {% for role in role_list %}
            {% set existing_for_role = existing_role_priv_map.get(role) if existing_role_priv_map.get(role) is not none else [] %}
            {% do log('====> Existing grants for role ' ~ role ~ ' on ' ~ object ~ ' : ' ~ (existing_for_role | join(', ')), info=True) %}
            {% for privilege in permission_list %}
                {% if privilege not in existing_for_role %}
                    {# This role needs this privilege - mark for bulk grant #}
                    {% if bulk_grant_needed.get(role) is none %}
                        {% set _ = bulk_grant_needed.update({role: []}) %}
                    {% endif %}
                    {% if privilege not in bulk_grant_needed.get(role) %}
                        {% do bulk_grant_needed.get(role).append(privilege) %}
                    {% endif %}
                {% endif %}
            {% endfor %}
        {% endfor %}
    {% endfor %}

    {# Second pass: generate bulk grant statements #}
    {% set bulk_grant_statements = [] %}
    {% for role in bulk_grant_needed.keys() %}
        {% for privilege in bulk_grant_needed.get(role) %}
            {# Check if ALL objects in the schema need this privilege for this role #}
            {% set objects_with_priv = all_existing_role_privs.get(role, {}).get(privilege, []) %}
            {% set objects_needing_priv = discovered_objects | length - (objects_with_priv | length) %}

            {% if objects_needing_priv > 0 %}
                {# Generate bulk grant statement #}
                {% set bulk_stmt = 'grant ' ~ privilege | lower ~ ' on all ' ~ object_type | lower ~ 's in schema ' ~ target.database ~ '.' ~ schema_name ~ ' to role ' ~ role | lower ~ ';' %}
                {% do bulk_grant_statements.append(bulk_stmt) %}
                {% do log('====> Bulk grant needed: ' ~ privilege ~ ' to ' ~ role ~ ' (' ~ objects_needing_priv ~ ' objects)', info=True) %}
            {% endif %}
        {% endfor %}
    {% endfor %}

    {% set total_revokes = revoke_statements | length %}
    {% set total_bulk_grants = bulk_grant_statements | length %}
    {% set all_statements = revoke_statements + bulk_grant_statements %}

    {% if all_statements | length == 0 %}
        {% do log('grant_schema_object_privileges: no changes required for ' ~ object_type ~ ' objects in schema ' ~ schema_name, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('grant_schema_object_privileges summary: ' ~ total_revokes ~ ' individual revokes, ' ~ total_bulk_grants ~ ' bulk grants (' ~ all_statements | length ~ ' total statements) for ' ~ object_type ~ ' objects in schema ' ~ schema_name, info=True) %}

    {# Execute statements if not in dry run mode #}
    {% if var('grants_dry_run', false) %}
        {% do log('DRY RUN MODE - statements would be:', info=True) %}
        {% if revoke_statements | length > 0 %}
            {% do log('=== Individual Revoke Statements ===', info=True) %}
            {% for stmt in revoke_statements %}
                {% do log(stmt, info=True) %}
            {% endfor %}
        {% endif %}
        {% if bulk_grant_statements | length > 0 %}
            {% do log('=== Bulk Grant Statements ===', info=True) %}
            {% for stmt in bulk_grant_statements %}
                {% do log(stmt, info=True) %}
            {% endfor %}
        {% endif %}
    {% else %}
        {# Execute revoke statements first #}
        {% if revoke_statements | length > 0 %}
            {% do log('=== Executing Individual Revoke Statements ===', info=True) %}
            {% for stmt in revoke_statements %}
                {% do log(stmt, info=True) %}
                {% set _ = run_query(stmt) %}
            {% endfor %}
        {% endif %}
        {# Then execute bulk grant statements #}
        {% if bulk_grant_statements | length > 0 %}
            {% do log('=== Executing Bulk Grant Statements ===', info=True) %}
            {% for stmt in bulk_grant_statements %}
                {% do log(stmt, info=True) %}
                {% set _ = run_query(stmt) %}
            {% endfor %}
        {% endif %}
    {% endif %}

    {% do log('grant_schema_object_privileges: completed privilege reconciliation for ' ~ object_type ~ ' objects in schema ' ~ schema_name, info=True) %}
{% endmacro %}