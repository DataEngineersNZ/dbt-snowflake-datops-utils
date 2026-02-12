{% macro get_grant_stream_ownership_sql(schema_list, role_name) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return([]) %}{% endif %}
    {% if not execute %}{% do return([]) %}{% endif %}
    {% set query %}
       show streams in database {{ target.database }}
       ->>
       select "schema_name" as schema_name, "name" as object_name
       from $1
       where "owner" != '{{ role_name | upper }}'
         and "schema_name" in ({{ schema_list }})
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results and results | length > 0 %}
        {% for r in results %}
            {% do statements.append('grant ownership on stream ' ~ target.database ~ '.' ~ r[0] ~ '.' ~ r[1] ~ ' to role ' ~ role_name ~ ' revoke current grants;') %}
        {% endfor %}
        {% do log('get_grant_stream_ownership_sql: generated ' ~ (statements | length) ~ ' statements', info=True) %}
    {% else %}
        {% do log('get_grant_stream_ownership_sql: no stream ownership changes required', info=True) %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}

