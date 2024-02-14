{% macro grant_schema_write_access(tables, grant_type, grant_roles) %}
    {% if flags.WHICH in ['run'] %}
       {% set existing_roles = []%}
       {% for table in tables %}
            {% do log("Granting " ~ grant_type ~ " for table " ~ table, info=True) %}
            {% set query %}
                show grants on table {{ target.database }}.{{ table }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege in [grant_type] %}
                        {% if row.grantee_name in grant_roles %}
                            {{ existing_roles.append(row.grantee_name) }}
                        {%endif%}
                    {%endif%}
                {% endfor %}
            {%endif%}
            {% for role in grant_roles %}
                {% if role not in existing_roles %}
                    {% set grant_query %}
                        grant {{ grant_type }} on table {{ target.database }}.{{ table }} to role {{ role }};
                    {% endset %}
                    {% set grant = run_query(grant_query) %}
                {%endif%}
            {% endfor %}
        {%endfor%}
    {% endif %}
{% endmacro %}
