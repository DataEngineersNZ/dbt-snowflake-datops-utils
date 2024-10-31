{% macro grant_integration_ownership(integration_name, role_name) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% do log("Adding Integration Ownership rights on " ~ integration_name ~ " for " ~ role_name, info=True) %}
        {% set query %}
        grant ownership on integration {{ integration_name }} to role {{ role_name }} revoke current grants;
        {% endset %}
        {% do run_query(query) %}
    {% endif %}
{% endmacro %}
