{% macro grant_database_role_inherited_privileges(object_type, permissions, database_roles, include_schemas=none, exclude_schemas=none) %}
    {# Grants Snowflake INHERITED privileges (GRANT INHERITED ... ON ALL <TYPE>S IN {DATABASE|SCHEMA} ... TO
       DATABASE ROLE ...) so the privilege automatically applies to every current and future object of the
       given type in scope. Three mutually exclusive scoping modes: an explicit include_schemas list, an
       exclude_schemas list (resolved against all schemas in the database via _grants_collect_schemas), or
       neither (whole database).

       SCHEMA is a special case only when include_schemas or exclude_schemas resolves to a concrete list of
       named schemas: a schema can't contain other schemas, so "GRANT INHERITED ... ON ALL SCHEMAS IN
       SCHEMA <name>" is invalid, and there's no native syntax to exclude specific schemas from an
       IN DATABASE grant either -- so for a named schema list (whichever of include/exclude produced it),
       SCHEMA-type privileges are granted directly on each named schema instead of via INHERITED.

       When NEITHER include_schemas nor exclude_schemas is supplied (true whole-database scope), SCHEMA
       behaves like any other object type: SCHEMA is a valid INHERITED target when the container is
       DATABASE (only SCHEMA-in-SCHEMA is rejected), so a single `GRANT INHERITED ... ON ALL SCHEMAS IN
       DATABASE ...` statement is used -- this also automatically covers schemas created later, which the
       named-list direct-grant path cannot (Snowflake has no "all current and future schemas except
       these" primitive).

       A named schema list that resolves to zero schemas (e.g. exclude_schemas excludes every schema in
       the database) correctly produces zero statements -- it must NOT fall back to whole-database scope.

       Executed unconditionally: there is no reliable pre-check for existing DATABASE_ROLE inherited
       grantees, and both GRANT INHERITED and the direct-grant fallback for a named SCHEMA list are
       idempotent (re-granting an already-held grant is a safe no-op). #}
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

    {# An explicitly empty include_schemas list means "scope to nothing", not "unset" -- without this
       check it would fall through to the exclude_schemas/whole-database branches below and grant far
       more broadly than an empty list implies. #}
    {% if include_schemas is not none and include_schemas | length == 0 %}
        {% do log('grant_database_role_inherited_privileges: include_schemas is an empty list, nothing to do', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set is_schema_type = object_type | upper == 'SCHEMA' %}
    {% set grant_statements = [] %}

    {% if include_schemas and include_schemas | length > 0 %}
        {% set schema_list = [include_schemas] if include_schemas is string else include_schemas %}
        {% do log('grant_database_role_inherited_privileges: using explicit include_schemas (' ~ (schema_list | length) ~ ' schema(s))', info=True) %}
        {% set has_named_list = true %}
    {% elif exclude_schemas is not none %}
        {% set schema_list = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
        {% do log('grant_database_role_inherited_privileges: using exclude_schemas, resolved ' ~ (schema_list | length) ~ ' schema(s)', info=True) %}
        {% set has_named_list = true %}
    {% else %}
        {% set schema_list = [] %}
        {% set has_named_list = false %}
        {% do log('grant_database_role_inherited_privileges: no schema filters supplied, scoping to IN DATABASE ' ~ target.database, info=True) %}
    {% endif %}

    {% if has_named_list %}
        {# A named list (from include_schemas or resolved exclude_schemas) may legitimately be empty --
           e.g. exclude_schemas excludes every schema -- in which case the for loops below simply produce
           zero statements. This must never fall back to whole-database scope. #}
        {% if is_schema_type %}
            {% for schema_name in schema_list %}
                {% for database_role in database_role_list %}
                    {% set stmt %}
                        grant {{ permission_list | join(', ') | lower }} on schema {{ target.database }}.{{ schema_name }} to database role {{ target.database }}.{{ database_role | lower }};
                    {% endset %}
                    {% do grant_statements.append(stmt | trim) %}
                {% endfor %}
            {% endfor %}
        {% else %}
            {% set plural_type = dbt_dataengineers_utils._grants_pluralize_object_type(object_type) | lower %}
            {% for schema_name in schema_list %}
                {% for database_role in database_role_list %}
                    {% set stmt %}
                        grant inherited {{ permission_list | join(', ') | lower }} on all {{ plural_type }} in schema {{ target.database }}.{{ schema_name }} to database role {{ target.database }}.{{ database_role | lower }};
                    {% endset %}
                    {% do grant_statements.append(stmt | trim) %}
                {% endfor %}
            {% endfor %}
        {% endif %}
    {% else %}
        {# Whole-database scope: SCHEMA is a valid INHERITED target when the container is DATABASE (only
           SCHEMA-in-SCHEMA is rejected), so this also covers schemas created later -- unlike the named-list
           direct-grant path above, which can only ever cover schemas that already exist. #}
        {% set plural_type = dbt_dataengineers_utils._grants_pluralize_object_type(object_type) | lower %}
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

    {% do log('grant_database_role_inherited_privileges: granting ' ~ (permission_list | join(', ')) ~ ' on ' ~ (object_type | lower) ~ ' object(s) to ' ~ (database_role_list | length) ~ ' database role(s)', info=True) %}
    {% for stmt in grant_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('grant_database_role_inherited_privileges: completed', info=True) %}
{% endmacro %}
