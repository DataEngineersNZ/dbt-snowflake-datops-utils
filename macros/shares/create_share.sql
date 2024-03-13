{% macro create_share(share_name, accounts, environments) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% if execute %}
            {% if target.name in environments %}
                {% do log("Creating or Updating Share" ~ share_name, info=True) %}
                {% set sql %}
                    create share if not exists {{ share_name }};
                    grant usage on database {{ target.database }} to share {{ share_name }};
                    {% for account in accounts %}
                        alter share {{ share_name }} add accounts = {{ account }};
                    {% endfor %}
                {% endset %}
                {% set results = run_query(sql) %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}