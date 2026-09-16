{% macro grant_database_role_to_role(database_role_name, role_names) %}
    {# Grants a database role to one or more account roles, creating a role hierarchy so the account
       role inherits the database role's privileges. Executed unconditionally: GRANT DATABASE ROLE is
       idempotent (re-granting an already-held database role is a safe no-op), and Snowflake does not
       support SHOW GRANTS OF DATABASE ROLE to reliably pre-check existing state. #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping grant_database_role_to_role: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_database_role_to_role: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if not database_role_name %}
        {% do log('grant_database_role_to_role: database_role_name must be supplied', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set role_list = dbt_dataengineers_utils._grants_normalize_roles(
        [role_names] if role_names is string else role_names
    ) %}

    {% if role_list | length == 0 %}
        {% do log('grant_database_role_to_role: no target roles supplied', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set grant_statements = [] %}
    {% for role_name in role_list %}
        {% do grant_statements.append('grant database role ' ~ target.database ~ '.' ~ (database_role_name | lower) ~ ' to role ' ~ (role_name | lower) ~ ';') %}
    {% endfor %}

    {% do log('grant_database_role_to_role: granting database role ' ~ database_role_name ~ ' to ' ~ (role_list | length) ~ ' role(s)', info=True) %}
    {% for stmt in grant_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('grant_database_role_to_role: completed', info=True) %}
{% endmacro %}
