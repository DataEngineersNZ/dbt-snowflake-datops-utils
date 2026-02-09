{% macro create_internal_share(share_name, reference_databases, environments) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% if execute %}
            {% if target.name in environments %}
                {% do log("Creating or Updating Share" ~ share_name, info=True) %}
                {% set sql %}
                    create share if not exists {{ share_name }} secure_objects_only=false;
                    grant usage on database {{ target.database }} to share {{ share_name }};
                    {% for reference_database in reference_databases %}
                        grant reference_usage on database {{ reference_database }} to share {{ share_name }};
                    {% endfor %}
                {% endset %}
                {% set results = run_query(sql) %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}