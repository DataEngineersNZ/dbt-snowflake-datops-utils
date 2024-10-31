{% macro grant_database_ownership(role_name) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% do log("Adding Database Ownership rights on " ~ target.database ~ " for " ~ role_name, info=True) %}
        {% set query %}
        grant ownership on database {{ target.database }} to role {{ role_name }} revoke current grants;
        {% endset %}
        {% do run_query(query) %}
    {% endif %}
{% endmacro %}
