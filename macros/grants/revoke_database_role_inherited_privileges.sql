{% macro revoke_database_role_inherited_privileges(object_type, permissions, database_roles, include_schemas=none, exclude_schemas=none) %}
    {# Revokes Snowflake INHERITED privileges (REVOKE INHERITED ... ON ALL <TYPE>S IN {DATABASE|SCHEMA} ...
       FROM DATABASE ROLE ...) from one or more database roles. Mirrors
       grant_database_role_inherited_privileges's three scoping modes and its SCHEMA special case:

       - include_schemas / exclude_schemas (a named schema list): SCHEMA-type privileges are revoked
         directly on each named schema (a schema can't contain other schemas, so "ON ALL SCHEMAS IN
         SCHEMA <name>" is invalid); non-SCHEMA types use REVOKE INHERITED per named schema. A named list
         that resolves to zero schemas (e.g. exclude_schemas excludes every schema) correctly produces
         zero statements -- it must NOT fall back to whole-database scope.
       - Neither supplied (true whole-database scope): SCHEMA is a valid INHERITED target when the
         container is DATABASE, so a single `REVOKE INHERITED ... ON ALL SCHEMAS IN DATABASE ...`
         statement is used, same as any other object type. This is required, not just preferred: if the
         role's existing grant for this scope was itself a database-level `GRANT INHERITED ... ON ALL
         SCHEMAS IN DATABASE`, revoking directly on each currently-existing schema would NOT remove that
         database-level grant (and would miss any schema created after the grant too) -- only a REVOKE
         INHERITED on the same DATABASE container actually removes it.

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
        {% set has_named_list = true %}
    {% elif exclude_schemas is not none %}
        {% set schema_list = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
        {% do log('revoke_database_role_inherited_privileges: using exclude_schemas, resolved ' ~ (schema_list | length) ~ ' schema(s)', info=True) %}
        {% set has_named_list = true %}
    {% else %}
        {% set schema_list = [] %}
        {% set has_named_list = false %}
        {% do log('revoke_database_role_inherited_privileges: no schema filters supplied, scoping to IN DATABASE ' ~ target.database, info=True) %}
    {% endif %}

    {% if has_named_list %}
        {% if is_schema_type %}
            {% for schema_name in schema_list %}
                {% for database_role in database_role_list %}
                    {% do revoke_statements.append('revoke ' ~ (permission_list | join(', ') | lower) ~ ' on schema ' ~ target.database ~ '.' ~ schema_name ~ ' from database role ' ~ target.database ~ '.' ~ (database_role | lower) ~ ';') %}
                {% endfor %}
            {% endfor %}
        {% else %}
            {% set plural_type = dbt_dataengineers_utils._grants_pluralize_object_type(object_type) | lower %}
            {% for schema_name in schema_list %}
                {% for database_role in database_role_list %}
                    {% set stmt %}
                        revoke inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in schema {{ target.database }}.{{ schema_name }} from database role {{ target.database }}.{{ database_role | lower }};
                    {% endset %}
                    {% do revoke_statements.append(stmt | trim) %}
                {% endfor %}
            {% endfor %}
        {% endif %}
    {% else %}
        {# Whole-database scope: must use REVOKE INHERITED on the DATABASE container (not direct per-schema
           revokes) so it actually removes a matching database-level GRANT INHERITED and covers schemas
           created since that grant was made -- see the macro-level note above. #}
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
