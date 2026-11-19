{% macro revoke_database_role_inherited_privileges(object_type, permissions, database_roles, include_schemas=none, exclude_schemas=none) %}
    {# Revokes Snowflake INHERITED privileges (REVOKE INHERITED ... ON ALL <TYPE>S IN {DATABASE|SCHEMA} ...
       FROM DATABASE ROLE ...) from one or more database roles. Mirrors
       grant_database_role_inherited_privileges's three scoping modes (include_schemas, exclude_schemas
       resolved via _grants_collect_schemas, or whole-database) and its SCHEMA special case: a schema
       can't contain other schemas, so a schema-level privilege is always revoked directly on each named
       schema instead of via REVOKE INHERITED, regardless of which scoping mode supplied the schema list
       (including whole-database, where every schema in the database is resolved via the same helper used
       for exclude_schemas, with an empty exclude list).

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

    {# An explicitly empty include_schemas list means "scope to nothing", not "unset" -- without this
       check it would fall through to the exclude_schemas/whole-database branches below and revoke far
       more broadly than an empty list implies. #}
    {% if include_schemas is not none and include_schemas | length == 0 %}
        {% do log('revoke_database_role_inherited_privileges: include_schemas is an empty list, nothing to do', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set is_schema_type = object_type | upper == 'SCHEMA' %}
    {% set revoke_statements = [] %}

    {% if include_schemas and include_schemas | length > 0 %}
        {% set schema_list = [include_schemas] if include_schemas is string else include_schemas %}
        {% do log('revoke_database_role_inherited_privileges: using explicit include_schemas (' ~ (schema_list | length) ~ ' schema(s))', info=True) %}
    {% elif exclude_schemas is not none %}
        {% set schema_list = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
        {% do log('revoke_database_role_inherited_privileges: using exclude_schemas, resolved ' ~ (schema_list | length) ~ ' schema(s)', info=True) %}
    {% elif is_schema_type %}
        {% set schema_list = dbt_dataengineers_utils._grants_collect_schemas([], is_exclude_list=true) %}
        {% do log('revoke_database_role_inherited_privileges: SCHEMA with no schema filters -- resolved all ' ~ (schema_list | length) ~ ' schema(s) in the database for direct revokes', info=True) %}
    {% else %}
        {% set schema_list = [] %}
        {% do log('revoke_database_role_inherited_privileges: no schema filters supplied, scoping to IN DATABASE ' ~ target.database, info=True) %}
    {% endif %}

    {% if is_schema_type %}
        {% for schema_name in schema_list %}
            {% for database_role in database_role_list %}
                {% for permission in permission_list %}
                    {% do revoke_statements.append('revoke ' ~ (permission | lower) ~ ' on schema ' ~ target.database ~ '.' ~ schema_name ~ ' from database role ' ~ target.database ~ '.' ~ (database_role | lower) ~ ';') %}
                {% endfor %}
            {% endfor %}
        {% endfor %}
    {% elif schema_list | length > 0 %}
        {% set plural_type = dbt_dataengineers_utils._grants_pluralize_object_type(object_type) | lower %}
        {% for schema_name in schema_list %}
            {% for database_role in database_role_list %}
                {% set stmt %}
                    revoke inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in schema {{ target.database }}.{{ schema_name }} from database role {{ target.database }}.{{ database_role | lower }};
                {% endset %}
                {% do revoke_statements.append(stmt | trim) %}
            {% endfor %}
        {% endfor %}
    {% else %}
        {% set plural_type = dbt_dataengineers_utils._grants_pluralize_object_type(object_type) | lower %}
        {% for database_role in database_role_list %}
            {% set stmt %}
                revoke inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in database {{ target.database }} from database role {{ target.database }}.{{ database_role | lower }};
            {% endset %}
            {% do revoke_statements.append(stmt | trim) %}
        {% endfor %}
    {% endif %}

    {% if revoke_statements | length == 0 %}
        {% do log('revoke_database_role_inherited_privileges: no statements generated', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('revoke_database_role_inherited_privileges: revoking ' ~ (permission_list | join(', ')) ~ ' on ' ~ (object_type | lower) ~ ' object(s) from ' ~ (database_role_list | length) ~ ' database role(s)', info=True) %}
    {% for stmt in revoke_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('revoke_database_role_inherited_privileges: completed', info=True) %}
{% endmacro %}
