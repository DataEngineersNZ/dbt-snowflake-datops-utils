{% macro get_grant_schema_ownership_sql(schema_list, role_name) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return([]) %}{% endif %}
    {% if not execute %}{% do return([]) %}{% endif %}
    {% set query %}
        select distinct schema_name
        from information_schema.schemata
        where schema_name in ({{ schema_list }})
          and schema_owner != '{{ role_name | upper }}'
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results and results | length > 0 %}
        {% for r in results %}
            {{ statements.append('grant ownership on schema ' ~ target.database ~ '.' ~ r[0] ~ ' to role ' ~ role_name ~ ' revoke current grants;') }}
        {% endfor %}
        {% do log('get_grant_schema_ownership_sql: generated ' ~ (statements | length) ~ ' statements', info=True) %}
    {% else %}
        {% do log('get_grant_schema_ownership_sql: no schema ownership changes required', info=True) %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}
