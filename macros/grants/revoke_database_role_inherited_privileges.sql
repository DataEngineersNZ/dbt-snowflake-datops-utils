{% macro revoke_database_role_inherited_privileges(object_type, permissions, database_roles, include_schemas=none, exclude_schemas=none) %}
    {# Revokes Snowflake INHERITED privileges (REVOKE INHERITED ... ON ALL <TYPE>S IN {DATABASE|SCHEMA} ...
       FROM DATABASE ROLE ...) from one or more database roles. Mirrors
       grant_database_role_inherited_privileges's three mutually exclusive scoping modes (include_schemas,
       then exclude_schemas resolved via _grants_collect_schemas, then whole-database IN DATABASE), but
       issues REVOKE instead of GRANT, and -- since a schema can't contain other schemas -- revokes a
       SCHEMA-type privilege directly on the named schema(s) rather than via INHERITED when include_schemas
       is supplied (mirroring how the grant-side macro hands SCHEMA + include_schemas off to
       grant_database_role_schema_privileges instead of GRANT INHERITED).
       Executed unconditionally: REVOKE on a privilege/scope the database role doesn't currently hold is a
       safe no-op in Snowflake, so no pre-check is required. #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping revoke_database_role_inherited_privileges: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping revoke_database_role_inherited_privileges: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set permission_list = [permissions] if permissions is string else permissions %}
    {% set database_role_list = dbt_dataengineers_utils._grants_normalize_roles(
        [database_roles] if database_roles is string else database_roles
    ) %}

    {% if permission_list | length == 0 or database_role_list | length == 0 %}
        {% do log('revoke_database_role_inherited_privileges: permissions and database_roles must be non-empty', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set revoke_statements = [] %}

    {% if object_type | upper == 'SCHEMA' and include_schemas and include_schemas | length > 0 %}
        {% set schema_list = [include_schemas] if include_schemas is string else include_schemas %}
        {% do log('revoke_database_role_inherited_privileges: SCHEMA + include_schemas -- revoking directly on named schema(s) rather than INHERITED', info=True) %}
        {% for schema_name in schema_list %}
            {% for database_role in database_role_list %}
                {% for permission in permission_list %}
                    {% do revoke_statements.append('revoke ' ~ (permission | lower) ~ ' on schema ' ~ target.database ~ '.' ~ schema_name ~ ' from database role ' ~ target.database ~ '.' ~ (database_role | lower) ~ ';') %}
                {% endfor %}
            {% endfor %}
        {% endfor %}
    {% else %}
        {% set plural_type = dbt_dataengineers_utils._grants_pluralize_object_type(object_type) | lower %}
        {% if include_schemas and include_schemas | length > 0 %}
            {% set schema_list = [include_schemas] if include_schemas is string else include_schemas %}
            {% do log('revoke_database_role_inherited_privileges: using explicit include_schemas (' ~ (schema_list | length) ~ ' schema(s))', info=True) %}
            {% for schema_name in schema_list %}
                {% for database_role in database_role_list %}
                    {% set stmt %}
                        revoke inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in schema {{ target.database }}.{{ schema_name }} from database role {{ target.database }}.{{ database_role | lower }};
                    {% endset %}
                    {% do revoke_statements.append(stmt | trim) %}
                {% endfor %}
            {% endfor %}
        {% elif exclude_schemas is not none %}
            {% set schema_list = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
            {% do log('revoke_database_role_inherited_privileges: using exclude_schemas, resolved ' ~ (schema_list | length) ~ ' schema(s)', info=True) %}
            {% for schema_name in schema_list %}
                {% for database_role in database_role_list %}
                    {% set stmt %}
                        revoke inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in schema {{ target.database }}.{{ schema_name }} from database role {{ target.database }}.{{ database_role | lower }};
                    {% endset %}
                    {% do revoke_statements.append(stmt | trim) %}
                {% endfor %}
            {% endfor %}
        {% else %}
            {% do log('revoke_database_role_inherited_privileges: no schema filters supplied, scoping to IN DATABASE ' ~ target.database, info=True) %}
            {% for database_role in database_role_list %}
                {% set stmt %}
                    revoke inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in database {{ target.database }} from database role {{ target.database }}.{{ database_role | lower }};
                {% endset %}
                {% do revoke_statements.append(stmt | trim) %}
            {% endfor %}
        {% endif %}
    {% endif %}

    {% if revoke_statements | length == 0 %}
        {% do log('revoke_database_role_inherited_privileges: no statements generated', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('revoke_database_role_inherited_privileges: revoking inherited ' ~ (permission_list | join(', ')) ~ ' on all ' ~ (object_type | lower) ~ ' object(s) from ' ~ (database_role_list | length) ~ ' database role(s)', info=True) %}
    {% for stmt in revoke_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('revoke_database_role_inherited_privileges: completed', info=True) %}
{% endmacro %}
