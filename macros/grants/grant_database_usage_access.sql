{% macro grant_database_usage_access(grant_roles) %}
    {% if flags.WHICH in ['run'] %}
        {% set existing_roles = []%}
        {% do log("Granting and Revoking Database Usage Grants", info=True) %}
        {% set query %}
            show grants on database {{ target.database }}
        {% endset %}
        {% set results = run_query(query) %}
        {% if execute %}
            {% for row in results %}
                {%if row.privilege == "USAGE" %}
                    {% if row.grantee_name not in grant_roles %}
                        {% set revoke_query %}
                            revoke usage on database {{ target.database }} from {{ row.grantee_name }};
                        {% endset %}
                        {% set revoke = run_query(revoke_query) %}
                    {%else%}
                        {{ existing_roles.append(row.grantee_name) }}
                    {%endif%}
                {%endif%}
            {% endfor %}
        {%endif%}
        {% for role in grant_roles %}
            {% if role not in existing_roles %}
                {% set grant_query %}
                     grant usage on database {{ target.database }} to role {{ role }};
                {% endset %}
                {% set grant = run_query(grant_query) %}
            {%endif%}
        {% endfor %}
    {% endif %}
{% endmacro %}