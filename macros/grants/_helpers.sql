{# Shared helper macros for grant management. Existing public macro signatures preserved elsewhere. #}
{#
Potential future consolidation ideas (kept as comments to avoid interface changes now):
 - Introduce generic _grants_reconcile_privileges(object_type, objects, desired_privs, roles, strategy='replace')
 - Cache SHOW statements per invocation via var('_grants_show_cache', {}) to reduce repetitive queries
 - Add JSON summary emitter macro to collate revokes/grants across multiple macro calls in a run
These ideas intentionally deferred to keep current refactor incremental.
#}

{% macro _grants_collect_schemas(exclude_schemas) %}
    {% set include_schemas = [] %}
    {% if exclude_schemas is not iterable %}
        {% set exclude_schemas = [] %}
    {% endif %}
    {% if "INFORMATION_SCHEMA" not in exclude_schemas %}
        {% do exclude_schemas.append("INFORMATION_SCHEMA") %}
    {% endif %}
    {% set query %}
        show schemas in database {{ target.database }};
    {% endset %}
    {% set results = run_query(query) %}
    {% if execute and results %}
        {% for row in results %}
            {% if row.name not in exclude_schemas and row.name not in include_schemas %}
                {% do include_schemas.append(row.name) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(include_schemas) %}
{% endmacro %}

{% macro _grants_format_list(list_values) %}
    {% if list_values | length == 0 %}
        {% do return('') %}
    {% endif %}
    {% set formatted = "'" ~ (list_values | join("', '")) ~ "'" %}
    {% do return(formatted) %}
{% endmacro %}

{% macro _grants_append_unique(list_var, value) %}
    {% if value not in list_var %}
        {% do list_var.append(value) %}
    {% endif %}
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

{# Row formatters for specific ownership object types #}
{% macro _fmt_schema_ownership(row) %}
    grant ownership on schema {{ target.database }}.{{ row[0] }} to role {{ var('current_role_name_override', '') or '' }} revoke current grants;
{% endmacro %}
