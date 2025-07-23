{% macro get_grant_stream_ownership_sql(schema_list, role_name) %}
    {% set query %}
       show streams in database {{ target.database }}
       ->>
       select "schema_name" as schema_name, "name" as object_name
       from $1
       where "owner" != '{{ role_name | upper }}'
       and "schema_name" in ({{ schema_list }});
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results | length > 0 %}
        {% for result in results %}
            {{ statements.append(" grant ownership on stream " ~ target.database ~ "." ~ result.schema_name ~ "." ~ result.object_name ~ " to role " ~ role_name ~ " revoke current grants;") }}
        {% endfor %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}

