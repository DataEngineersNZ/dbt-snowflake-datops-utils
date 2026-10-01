{% macro grant_database_role_inherited_privileges(object_type, permissions, database_roles, include_schemas=none, exclude_schemas=none) %}
    {# Grants Snowflake INHERITED privileges (GRANT INHERITED ... ON ALL <TYPE>S IN {DATABASE|SCHEMA} ... TO
       DATABASE ROLE ...) so the privilege automatically applies to every current and future object of the
       given type in scope. Three mutually exclusive modes, resolved in this order:
         1. include_schemas supplied -> one statement per (schema, role).
         2. include_schemas empty/none but exclude_schemas supplied -> resolve schemas via
            _grants_collect_schemas(exclude_schemas, is_exclude_list=true), then one statement per
            (resolved schema, role). This is how database-wide reach with exclusions is achieved, since
            GRANT INHERITED ... IN DATABASE has no native exclusion syntax.
         3. Neither supplied -> a single statement per role scoped to IN DATABASE (true whole-database
            reach, no per-schema enumeration).
       Executed unconditionally: there is no reliable pre-check for existing DATABASE_ROLE inherited
       grantees, and GRANT INHERITED is idempotent (re-granting an already-held inherited grant is a
       safe no-op). #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping grant_database_role_inherited_privileges: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_database_role_inherited_privileges: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set permission_list = [permissions] if permissions is string else permissions %}
    {% set database_role_list = dbt_dataengineers_utils._grants_normalize_roles(
        [database_roles] if database_roles is string else database_roles
    ) %}

    {% if permission_list | length == 0 or database_role_list | length == 0 %}
        {% do log('grant_database_role_inherited_privileges: permissions and database_roles must be non-empty', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set plural_type = dbt_dataengineers_utils._grants_pluralize_object_type(object_type) | lower %}
    {% set grant_statements = [] %}

    {% if include_schemas and include_schemas | length > 0 %}
        {% set schema_list = [include_schemas] if include_schemas is string else include_schemas %}
        {% do log('grant_database_role_inherited_privileges: using explicit include_schemas (' ~ (schema_list | length) ~ ' schema(s))', info=True) %}
        {% for schema_name in schema_list %}
            {% for database_role in database_role_list %}
                {% set stmt %}
                    grant inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in schema {{ target.database }}.{{ schema_name }} to database role {{ target.database }}.{{ database_role | lower }};
                {% endset %}
                {% do grant_statements.append(stmt | trim) %}
            {% endfor %}
        {% endfor %}
    {% elif exclude_schemas is not none %}
        {% set schema_list = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
        {% do log('grant_database_role_inherited_privileges: using exclude_schemas, resolved ' ~ (schema_list | length) ~ ' schema(s)', info=True) %}
        {% for schema_name in schema_list %}
            {% for database_role in database_role_list %}
                {% set stmt %}
                    grant inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in schema {{ target.database }}.{{ schema_name }} to database role {{ target.database }}.{{ database_role | lower }};
                {% endset %}
                {% do grant_statements.append(stmt | trim) %}
            {% endfor %}
        {% endfor %}
    {% else %}
        {% do log('grant_database_role_inherited_privileges: no schema filters supplied, scoping to IN DATABASE ' ~ target.database, info=True) %}
        {% for database_role in database_role_list %}
            {% set stmt %}
                grant inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in database {{ target.database }} to database role {{ target.database }}.{{ database_role | lower }};
            {% endset %}
            {% do grant_statements.append(stmt | trim) %}
        {% endfor %}
    {% endif %}

    {% if grant_statements | length == 0 %}
        {% do log('grant_database_role_inherited_privileges: no statements generated', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('grant_database_role_inherited_privileges: granting inherited ' ~ (permission_list | join(', ')) ~ ' on all ' ~ plural_type ~ ' to ' ~ (database_role_list | length) ~ ' database role(s)', info=True) %}
    {% for stmt in grant_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('grant_database_role_inherited_privileges: completed', info=True) %}
{% endmacro %}
