{% macro grant_database_role_to_application(database_role_name, application_names) %}
    {# Grants a database role to one or more Snowflake Native Apps, allowing the application to inherit
       the database role's privileges. Executed unconditionally: GRANT DATABASE ROLE is idempotent
       (re-granting an already-held database role is a safe no-op), and Snowflake does not support
       SHOW GRANTS OF DATABASE ROLE to reliably pre-check existing state. #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping grant_database_role_to_application: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_database_role_to_application: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if not database_role_name %}
        {% do log('grant_database_role_to_application: database_role_name must be supplied', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set application_list = dbt_dataengineers_utils._grants_normalize_roles(
        [application_names] if application_names is string else application_names
    ) %}

    {% if application_list | length == 0 %}
        {% do log('grant_database_role_to_application: no target applications supplied', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set grant_statements = [] %}
    {% for application_name in application_list %}
        {% do grant_statements.append('grant database role ' ~ target.database ~ '.' ~ (database_role_name | lower) ~ ' to application ' ~ (application_name | lower) ~ ';') %}
    {% endfor %}

    {% do log('grant_database_role_to_application: granting database role ' ~ database_role_name ~ ' to ' ~ (application_list | length) ~ ' application(s)', info=True) %}
    {% for stmt in grant_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('grant_database_role_to_application: completed', info=True) %}
{% endmacro %}
