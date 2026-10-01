{% macro grant_database_role_object_by_prefix(object_type, prefix, grant_types, database_roles, include_schemas=none, exclude_schemas=none) %}
    {# Grants a database role on objects whose name starts with a given prefix. Neither GRANT INHERITED
       nor the bulk ON ALL <TYPE>S syntax supports name-pattern filtering, so this macro first discovers
       matching object names via SHOW <TYPE>S LIKE '<prefix>%' IN SCHEMA ... (Snowflake's SHOW command
       supports a LIKE clause for every object kind -- tables, views, functions, stages, etc.), then
       delegates the actual grant + idempotency check to the existing grant_database_role_object macro.
       Schema resolution mirrors grant_database_role_inherited_privileges's three modes:
         1. include_schemas supplied -> use as-is.
         2. include_schemas empty/none but exclude_schemas supplied -> resolve via
            _grants_collect_schemas(exclude_schemas, is_exclude_list=true).
         3. Neither supplied -> resolve every schema in the database via
            _grants_collect_schemas([], is_exclude_list=true) (auto-excludes INFORMATION_SCHEMA). #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping grant_database_role_object_by_prefix: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_database_role_object_by_prefix: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if not prefix %}
        {% do log('grant_database_role_object_by_prefix: prefix must be supplied', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if include_schemas and include_schemas | length > 0 %}
        {% set schema_list = [include_schemas] if include_schemas is string else include_schemas %}
    {% elif exclude_schemas is not none %}
        {% set schema_list = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}
    {% else %}
        {% set schema_list = dbt_dataengineers_utils._grants_collect_schemas([], is_exclude_list=true) %}
    {% endif %}

    {% if schema_list | length == 0 %}
        {% do log('grant_database_role_object_by_prefix: no schemas to process', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set plural_type = dbt_dataengineers_utils._grants_pluralize_object_type(object_type) | lower %}
    {% set safe_prefix = prefix | replace("'", "''") %}
    {% set objects = [] %}

    {% for schema_name in schema_list %}
        {% set discovery_query %}
            show {{ plural_type }} like '{{ safe_prefix }}%' in schema {{ target.database }}.{{ schema_name }};
        {% endset %}
        {% set results = run_query(discovery_query) %}
        {% if results %}
            {% for row in results %}
                {% do objects.append(schema_name ~ '.' ~ row.name) %}
            {% endfor %}
        {% endif %}
    {% endfor %}

    {% if objects | length == 0 %}
        {% do log('grant_database_role_object_by_prefix: no ' ~ plural_type ~ ' matched prefix "' ~ prefix ~ '" across ' ~ (schema_list | length) ~ ' schema(s)', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('grant_database_role_object_by_prefix: found ' ~ (objects | length) ~ ' ' ~ plural_type ~ ' matching prefix "' ~ prefix ~ '" across ' ~ (schema_list | length) ~ ' schema(s); delegating to grant_database_role_object', info=True) %}
    {% do return(dbt_dataengineers_utils.grant_database_role_object(object_type, objects, grant_types, database_roles)) %}
{% endmacro %}
