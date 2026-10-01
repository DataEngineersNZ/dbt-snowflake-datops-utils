{% macro grant_database_role_schema_privileges(permissions, schema_names, database_roles) %}
    {# Grants schema-level privileges (e.g. USAGE, MONITOR, CREATE TABLE) on one or more schemas to
       one or more database roles. GRANT statements are executed unconditionally rather than checked
       against existing state first: information_schema.object_privileges does not reliably surface
       DATABASE_ROLE grantees, and Snowflake GRANT statements are inherently idempotent (re-granting an
       already-held privilege is a safe no-op), so a pre-check would add complexity without changing
       behaviour. #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping grant_database_role_schema_privileges: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_database_role_schema_privileges: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set permission_list = [permissions] if permissions is string else permissions %}
    {% set schema_list = [schema_names] if schema_names is string else schema_names %}
    {% set database_role_list = dbt_dataengineers_utils._grants_normalize_roles(
        [database_roles] if database_roles is string else database_roles
    ) %}

    {% if permission_list | length == 0 or schema_list | length == 0 or database_role_list | length == 0 %}
        {% do log('grant_database_role_schema_privileges: permissions, schema_names, and database_roles must all be non-empty', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set grant_statements = [] %}
    {% for schema_name in schema_list %}
        {% for database_role in database_role_list %}
            {% set stmt %}
                grant {{ permission_list | join(', ') | lower }} on schema {{ target.database }}.{{ schema_name }} to database role {{ target.database }}.{{ database_role | lower }};
            {% endset %}
            {% do grant_statements.append(stmt | trim) %}
        {% endfor %}
    {% endfor %}

    {% do log('grant_database_role_schema_privileges: granting ' ~ (permission_list | join(', ')) ~ ' on ' ~ (schema_list | length) ~ ' schema(s) to ' ~ (database_role_list | length) ~ ' database role(s)', info=True) %}
    {% for stmt in grant_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('grant_database_role_schema_privileges: completed', info=True) %}
{% endmacro %}
