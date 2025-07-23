{% macro get_grant_task_ownership_sql(schema_list, role_name) %}
    {% set query %}
       show tasks in database {{ target.database }}
       ->>
       select "schema_name" as schema_name, "name" as task_name
       from $1
       where "owner" != '{{ role_name | upper }}'
       and "schema_name" in ({{ schema_list }});
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results | length > 0 %}
        {% for result in results %}
            {{ statements.append(" grant ownership on task " ~ target.database ~ "." ~ result.schema_name ~ "." ~ result.task_name ~ " to role " ~ role_name ~ " revoke current grants;") }}
        {% endfor %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}

