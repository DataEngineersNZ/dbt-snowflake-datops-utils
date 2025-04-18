{% macro grant_integration_usage(integration_name, role_name) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% do log("Adding Integration Usage rights on " ~ integration_name ~ " for " ~ role_name, info=True) %}
        {% set query %}
        grant usage on integration {{ integration_name }} to role {{ role_name }} ;
        {% endset %}
        {% do run_query(query) %}
    {% endif %}
{% endmacro %}
