{% macro revoke_database_role_object(object_type, objects, grant_types, database_roles) %}
    {# Revokes privileges on specific objects from one or more database roles. Mirrors
       grant_database_role_object's signature and object-identifier conventions but issues REVOKE
       statements unconditionally -- revoking a privilege a database role doesn't currently hold is a
       safe no-op in Snowflake, so no SHOW GRANTS pre-check is required (unlike the grant-side macro,
       which checks first to avoid redundant GRANT statements). #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping revoke_database_role_object: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping revoke_database_role_object: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if objects | length == 0 %}
        {% do log('revoke_database_role_object: no objects supplied for ' ~ object_type, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set database_role_list = dbt_dataengineers_utils._grants_normalize_roles(
        [database_roles] if database_roles is string else database_roles
    ) %}
    {% set grant_type_list = ([grant_types] if grant_types is string else grant_types) | map('upper') | list %}

    {% if database_role_list | length == 0 or grant_type_list | length == 0 %}
        {% do log('revoke_database_role_object: grant_types and database_roles must be non-empty', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set revoke_statements = [] %}
    {% for object in objects %}
        {% for database_role in database_role_list %}
            {% for privilege in grant_type_list %}
                {% do revoke_statements.append('revoke ' ~ (privilege | lower) ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' from database role ' ~ target.database ~ '.' ~ (database_role | lower) ~ ';') %}
            {% endfor %}
        {% endfor %}
    {% endfor %}

    {% do log('revoke_database_role_object: revoking ' ~ (grant_type_list | join(', ')) ~ ' on ' ~ (objects | length) ~ ' ' ~ object_type ~ ' object(s) from ' ~ (database_role_list | length) ~ ' database role(s)', info=True) %}
    {% for stmt in revoke_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('revoke_database_role_object: completed', info=True) %}
{% endmacro %}
