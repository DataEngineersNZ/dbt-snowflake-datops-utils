{# Shared helper macros for grant management. Existing public macro signatures preserved elsewhere. #}
{#
Potential future consolidation ideas (kept as comments to avoid interface changes now):
 - Introduce generic _grants_reconcile_privileges(object_type, objects, desired_privs, roles, strategy='replace')
 - Cache SHOW statements per invocation via var('_grants_show_cache', {}) to reduce repetitive queries
 - Add JSON summary emitter macro to collate revokes/grants across multiple macro calls in a run
These ideas intentionally deferred to keep current refactor incremental.
#}

{% macro _grants_collect_schemas(schema_names, is_exclude_list=true) %}
    {% set include_schemas = [] %}
    {% if schema_names is not iterable %}
        {% set schema_names = [] %}
    {% endif %}
    {% if "INFORMATION_SCHEMA" not in schema_names and is_exclude_list %}
        {% do schema_names.append("INFORMATION_SCHEMA") %}
    {% endif %}
    {% set query %}
        show schemas in database {{ target.database }};
    {% endset %}
    {% set results = run_query(query) %}
    {% if execute and results %}
        {% for row in results %}
            {% if row.name not in include_schemas %}
                {% if is_exclude_list %}
                    {% if row.name not in schema_names %}
                        {% do include_schemas.append(row.name) %}
                    {% endif %}
                {% else %}
                    {% if row.name in schema_names %}
                        {% do include_schemas.append(row.name) %}
                    {% endif %}
                {% endif %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(include_schemas) %}
{% endmacro %}

{% macro _grants_format_list(list_values) %}
    {% if list_values | length == 0 %}
        {% do return('') %}
    {% endif %}
    {% set escaped_list = list_values | map('replace', "'", "''") | list %}
    {% set formatted = "'" ~ (escaped_list | join("', '")) ~ "'" %}
    {% do return(formatted) %}
{% endmacro %}

{% macro _grants_append_unique(list_var, value) %}
    {% if value not in list_var %}
        {% do list_var.append(value) %}
    {% endif %}
{% endmacro %}

{# Normalize a list of role/grantee names to uppercase for case-insensitive comparison #}
{% macro _grants_normalize_roles(roles) %}
    {% do return(roles | map('upper') | list) %}
{% endmacro %}

{% macro _grants_log_list(prefix, items) %}
    {% do log(prefix ~ (items | join(', ')), info=True) %}
{% endmacro %}

{% macro _grants_execute(statements, label) %}
    {% if statements | length == 0 %}
        {% do log('No statements to execute for ' ~ label, info=True) %}
        {% do return(0) %}
    {% endif %}
    {% do log('Executing ' ~ (statements | length) ~ ' statements for ' ~ label, info=True) %}
    {% for s in statements %}
        {% if s %}
            {% do log(s, info=True) %}
            {% set _ = run_query(s) %}
        {% endif %}
    {% endfor %}
    {% do log('Completed executing ' ~ (statements | length) ~ ' statements for ' ~ label, info=True) %}
    {% do return(statements | length) %}
{% endmacro %}

{# Collect all role names in the account (simple cache pattern using var) #}
{% macro _grants_collect_roles() %}
    {% set roles = [] %}
    {% set query %} show roles {% endset %}
    {% set results = run_query(query) %}
    {% if execute and results %}
        {% for row in results %}
            {% if row.name not in roles %}
                {% do roles.append(row.name) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(roles) %}
{% endmacro %}

{# Generic ownership query runner returning result rows (list) #}
{% macro _ownership_run(query) %}
    {% set results = run_query(query) %}
    {% if results %}
        {% do return(results) %}
    {% else %}
        {% do return([]) %}
    {% endif %}
{% endmacro %}

{# Generic ownership statement builder.
   Parameters:
     object_rows: results from run_query
     formatter: expects a macro name (string) to call with each row to produce statement or none.
 #}
{% macro _ownership_build(object_rows, formatter) %}
    {% set statements = [] %}
    {% if object_rows | length > 0 %}
        {% for r in object_rows %}
            {% set stmt = call(attribute(dbt_dataengineers_utils, formatter), r) %}
            {% if stmt %}
                {% do statements.append(stmt) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}

{# Bulk check: returns dict {role: [privs]} for a given schema from information_schema.object_privileges.
   Filters by optional privilege_types list, grantee list, and object_type.
   Grantees are normalized to uppercase internally. #}
{% macro _grants_get_schema_object_privs(schema, privilege_types, grantees, object_type=none) %}
    {% set result_map = {} %}
    {% set priv_filter = privilege_types | map('upper') | list %}
    {% set grantees_upper = grantees | map('upper') | list %}
    {% set query %}
        select privilege_type, grantee
        from information_schema.object_privileges
        where object_schema = '{{ schema }}'
        {% if priv_filter | length > 0 %}
          and privilege_type in ('{{ priv_filter | join("', '") }}')
        {% endif %}
        {% if grantees_upper | length > 0 %}
          and grantee in ('{{ grantees_upper | join("', '") }}')
        {% endif %}
        {% if object_type is not none %}
          and object_type = '{{ object_type | upper }}'
        {% endif %}
        and grantor is not null
    {% endset %}
    {% set results = run_query(query) %}
    {% if execute and results %}
        {% for row in results %}
            {% if result_map.get(row[1]) is none %}
                {% set _ = result_map.update({row[1]: []}) %}
            {% endif %}
            {% if row[0] not in result_map.get(row[1]) %}
                {% do result_map.get(row[1]).append(row[0]) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(result_map) %}
{% endmacro %}

{# Check schema-level grants (USAGE etc) for given roles. Returns list of roles (uppercased) that already have the privilege. #}
{% macro _grants_get_schema_grants(schema, privilege, grantee_type) %}
    {% set existing = [] %}
    {% set query %}
        show grants on schema {{ target.database }}.{{ schema }};
    {% endset %}
    {% set results = run_query(query) %}
    {% if execute and results %}
        {% for row in results %}
            {% if row.privilege == privilege and row.granted_to == grantee_type %}
                {% if row.grantee_name | upper not in existing %}
                    {% do existing.append(row.grantee_name | upper) %}
                {% endif %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(existing) %}
{% endmacro %}

{# Check future grants in a schema. Returns dict {role: [privs]} of existing future grants. #}
{% macro _grants_get_future_grants(schema) %}
    {% set result_map = {} %}
    {% set query %}
        show future grants in schema {{ target.database }}.{{ schema }};
    {% endset %}
    {% set results = run_query(query) %}
    {% if execute and results %}
        {% for row in results %}
            {% set _role = row.grantee_name %}
            {% set _priv = row.privilege %}
            {% if result_map.get(_role) is none %}
                {% set _ = result_map.update({_role: []}) %}
            {% endif %}
            {% set _key = _priv ~ ':' ~ row.grant_on %}
            {% if _key not in result_map.get(_role) %}
                {% do result_map.get(_role).append(_key) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(result_map) %}
{% endmacro %}

{# Row formatters for specific ownership object types #}
{% macro _fmt_schema_ownership(row) %}
    grant ownership on schema {{ target.database }}.{{ row[0] }} to role {{ var('current_role_name_override', '') or '' }} revoke current grants;
{% endmacro %}
