{% macro get_grant_network_rule_ownership_sql(schema_list, role_name) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return([]) %}{% endif %}
    {% if not execute %}{% do return([]) %}{% endif %}
    {% set query %}
       show network rules in database {{ target.database }}
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
            {{ statements.append('grant ownership on network rule ' ~ target.database ~ '.' ~ r[0] ~ '.' ~ r[1] ~ ' to role ' ~ role_name ~ ' revoke current grants;') }}
        {% endfor %}
        {% do log('get_grant_network_rule_ownership_sql: generated ' ~ (statements | length) ~ ' statements', info=True) %}
    {% else %}
        {% do log('get_grant_network_rule_ownership_sql: no network rule ownership changes required', info=True) %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}

