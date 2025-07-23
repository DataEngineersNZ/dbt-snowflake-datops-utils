{% macro get_grant_schema_ownership_sql(schema_list, role_name) %}

    {% set query %}
        select distinct
            schema_name
        from information_schema.schemata
        where schema_name in ({{ schema_list }})
        and schema_owner != '{{ role_name | upper }}'
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results | length > 0 %}
        {% for result in results %}
            {{ statements.append(" grant ownership on schema " ~ target.database ~ "." ~ result[0] ~ " to role " ~ role_name ~ " revoke current grants;") }}
        {% endfor %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}
