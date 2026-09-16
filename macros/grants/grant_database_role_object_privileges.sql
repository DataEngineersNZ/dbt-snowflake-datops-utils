{% macro grant_database_role_object_privileges(object_type, schema_names, permissions, database_roles) %}
    {# Grants privileges on ALL objects of a specific type within one or more schemas to one or more
       database roles, using bulk GRANT ... ON ALL <type>S IN SCHEMA statements. Executed unconditionally
       (see grant_database_role_schema_privileges for why: information_schema.object_privileges does not
       reliably surface DATABASE_ROLE grantees, and GRANT is inherently idempotent). #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping grant_database_role_object_privileges: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_database_role_object_privileges: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set permission_list = [permissions] if permissions is string else permissions %}
    {% set schema_list = [schema_names] if schema_names is string else schema_names %}
    {% set database_role_list = dbt_dataengineers_utils._grants_normalize_roles(
        [database_roles] if database_roles is string else database_roles
    ) %}

    {% if permission_list | length == 0 or schema_list | length == 0 or database_role_list | length == 0 %}
        {% do log('grant_database_role_object_privileges: object_type, permissions, schema_names, and database_roles must all be non-empty', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set grant_statements = [] %}
    {% for schema_name in schema_list %}
        {% for database_role in database_role_list %}
            {% set stmt %}
                grant {{ permission_list | join(', ') | lower }} on all {{ object_type | lower }}s in schema {{ target.database }}.{{ schema_name }} to database role {{ target.database }}.{{ database_role | lower }};
            {% endset %}
            {% do grant_statements.append(stmt | trim) %}
        {% endfor %}
    {% endfor %}

    {% do log('grant_database_role_object_privileges: granting ' ~ (permission_list | join(', ')) ~ ' on all ' ~ (object_type | lower) ~ 's in ' ~ (schema_list | length) ~ ' schema(s) to ' ~ (database_role_list | length) ~ ' database role(s)', info=True) %}
    {% for stmt in grant_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('grant_database_role_object_privileges: completed', info=True) %}
{% endmacro %}
