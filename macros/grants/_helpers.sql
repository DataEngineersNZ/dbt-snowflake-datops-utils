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

{# Check if roles have FULL privilege coverage on all objects in a schema.
   Returns dict {role: [priv_types_with_full_coverage]}.
   A privilege type is "fully covered" when the count of objects with that grant equals the total count of objects. #}
{% macro _grants_get_schema_full_coverage(schema, privilege_types, grantees) %}
    {% set result_map = {} %}
    {% set priv_filter = privilege_types | map('upper') | list %}
    {% set grantees_upper = grantees | map('upper') | list %}
    {% if grantees_upper | length == 0 or priv_filter | length == 0 %}
        {% do return(result_map) %}
    {% endif %}
    {% set query %}
        with object_counts as (
            select obj_type, count(*) as total_count
            from (
                select
                    case
                        when table_type = 'VIEW' then 'VIEW'
                        when table_type = 'MATERIALIZED VIEW' then 'MATERIALIZED VIEW'
                        when table_type = 'EXTERNAL TABLE' then 'EXTERNAL TABLE'
                        when is_dynamic = 'YES' then 'DYNAMIC TABLE'
                        when table_type = 'BASE TABLE' then 'TABLE'
                        else table_type
                    end as obj_type,
                    table_name as object_name
                from information_schema.tables
                where table_schema = '{{ schema }}'
                union all
                select object_type as obj_type, object_name
                from (
                    select distinct object_type, object_name
                    from information_schema.object_privileges
                    where object_schema = '{{ schema }}'
                      and object_type in ('STREAM', 'STAGE')
                      and grantor is not null
                )
            ) all_objects
            group by obj_type
        ),
        granted_counts as (
            select
                op.grantee,
                op.privilege_type,
                case
                    when t.table_type = 'VIEW' then 'VIEW'
                    when t.table_type = 'MATERIALIZED VIEW' then 'MATERIALIZED VIEW'
                    when t.table_type = 'EXTERNAL TABLE' then 'EXTERNAL TABLE'
                    when t.is_dynamic = 'YES' then 'DYNAMIC TABLE'
                    when t.table_type = 'BASE TABLE' then 'TABLE'
                    when t.table_type is not null then t.table_type
                    else op.object_type
                end as resolved_type,
                count(distinct op.object_name) as granted_count
            from information_schema.object_privileges op
            left join information_schema.tables t
                on op.object_name = t.table_name
                and op.object_schema = t.table_schema
            where op.object_schema = '{{ schema }}'
              and op.privilege_type in ('{{ priv_filter | join("', '") }}')
              and op.grantee in ('{{ grantees_upper | join("', '") }}')
              and op.grantor is not null
            group by op.grantee, op.privilege_type, resolved_type
        )
        select
            g.grantee,
            g.privilege_type,
            g.resolved_type as object_type
        from granted_counts g
        inner join object_counts o
            on g.resolved_type = o.obj_type
        where g.granted_count >= o.total_count
    {% endset %}
    {% set results = run_query(query) %}
    {% if execute and results %}
        {% for row in results %}
            {% set role = row[0] %}
            {% set priv = row[1] %}
            {% set obj_type = row[2] %}
            {% set key = priv ~ ':' ~ obj_type %}
            {% if result_map.get(role) is none %}
                {% set _ = result_map.update({role: []}) %}
            {% endif %}
            {% if key not in result_map.get(role) %}
                {% do result_map.get(role).append(key) %}
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

{# Detect which object types exist in a schema. Returns a list of type strings.
   Types returned: 'TABLE', 'VIEW', 'MATERIALIZED VIEW', 'EXTERNAL TABLE', 'DYNAMIC TABLE', 'STREAM', 'STAGE', 'PIPE', 'TASK' #}
{% macro _grants_get_schema_object_types(schema) %}
    {% set object_types = [] %}
    {# Table-like objects from information_schema.tables #}
    {% set query %}
        select distinct
            case
                when is_dynamic = 'YES' then 'DYNAMIC TABLE'
                when table_type = 'BASE TABLE' then 'TABLE'
                when table_type = 'EXTERNAL TABLE' then 'EXTERNAL TABLE'
                when table_type = 'MATERIALIZED VIEW' then 'MATERIALIZED VIEW'
                else table_type
            end as object_type
        from information_schema.tables
        where table_schema = '{{ schema }}'
    {% endset %}
    {% set results = run_query(query) %}
    {% if execute and results %}
        {% for row in results %}
            {% if row[0] not in object_types %}
                {% do object_types.append(row[0]) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {# Non-table objects: query information_schema.object_privileges for existence (avoids SHOW commands) #}
    {% set other_types_query %}
        select distinct object_type
        from information_schema.object_privileges
        where object_schema = '{{ schema }}'
          and object_type in ('STREAM', 'STAGE', 'PIPE', 'TASK')
    {% endset %}
    {% set other_results = run_query(other_types_query) %}
    {% if execute and other_results %}
        {% for row in other_results %}
            {% if row[0] not in object_types %}
                {% do object_types.append(row[0]) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(object_types) %}
{% endmacro %}

{# Bulk version: detect object types for ALL schemas in the database in two queries.
   Returns a dict {schema_name: [object_types]}. Call once per run and pass the result around. #}
{% macro _grants_get_all_schema_object_types() %}
    {% set schema_map = {} %}
    {# Table-like objects #}
    {% set query %}
        select table_schema,
            case
                when is_dynamic = 'YES' then 'DYNAMIC TABLE'
                when table_type = 'BASE TABLE' then 'TABLE'
                when table_type = 'EXTERNAL TABLE' then 'EXTERNAL TABLE'
                when table_type = 'MATERIALIZED VIEW' then 'MATERIALIZED VIEW'
                else table_type
            end as object_type
        from information_schema.tables
        group by table_schema, object_type
    {% endset %}
    {% set results = run_query(query) %}
    {% if execute and results %}
        {% for row in results %}
            {% set s = row[0] %}
            {% if schema_map.get(s) is none %}
                {% set _ = schema_map.update({s: []}) %}
            {% endif %}
            {% if row[1] not in schema_map.get(s) %}
                {% do schema_map.get(s).append(row[1]) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {# Non-table objects from object_privileges #}
    {% set other_query %}
        select distinct object_schema, object_type
        from information_schema.object_privileges
        where object_type in ('STREAM', 'STAGE', 'PIPE', 'TASK')
    {% endset %}
    {% set other_results = run_query(other_query) %}
    {% if execute and other_results %}
        {% for row in other_results %}
            {% set s = row[0] %}
            {% if schema_map.get(s) is none %}
                {% set _ = schema_map.update({s: []}) %}
            {% endif %}
            {% if row[1] not in schema_map.get(s) %}
                {% do schema_map.get(s).append(row[1]) %}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(schema_map) %}
{% endmacro %}

{# Row formatters for specific ownership object types #}
{% macro _fmt_schema_ownership(row) %}
    grant ownership on schema {{ target.database }}.{{ row[0] }} to role {{ var('current_role_name_override', '') or '' }} revoke current grants;
{% endmacro %}
