{% macro grant_schema_operate_access(exclude_schemas, grant_roles) %}
    {% if "INFORMATION_SCHEMA" not in exclude_schemas %}
        {{ exclude_schemas.append("INFORMATION_SCHEMA") }}
    {% endif %}
    {% if flags.WHICH in ['run'] %}
        {% set query %}
            show schemas in database {{ target.database }};
        {% endset %}
        {% set results = run_query(query) %}
        {% if execute %}
            {% for row in results %}
                {% set schema = row.name %}
                {% set include_schemas = [] %}
                {% if schema not in exclude_schemas %}
                    {{ include_schemas.append(schema) }}
                {% endif %}
            {% endfor %}
            {% if include_schemas | length > 0%}
                {% do grant_schema_operate_access_specific(include_schemas, grant_roles, true) %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}

{% macro grant_schema_operate_access_specific(schemas, grant_roles, revoke_current_grants) %}
    {% if flags.WHICH in ['run'] %}
       {% set existing_roles = []%}
       {% for schema in schemas %}
            {% do log("Granting and Revoking Schema Operate Grants", info=True) %}
            {% set query %}
                show grants on schema {{ target.database }}.{{ schema }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege in ["OPERATE"] %}
                        {% if row.grantee_name not in grant_roles %}
                            {% if revoke_current_grants %}
                                {% set revoke_query %}
                                    revoke {{ row.privilege }} in schema {{ target.database }}.{{ schema }} from role {{ row.grantee_name }};
                                {% endset %}
                                {% set revoke = run_query(revoke_query) %}
                            {% endif %}
                        {%else%}
                            {{ existing_roles.append(row.grantee_name) }}
                        {%endif%}
                    {%endif%}
                {% endfor %}
            {%endif%}
            {% for role in grant_roles %}
                {% if role not in existing_roles %}
                    {% set grant_query %}
                        grant usage on schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant operate on all pipes in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant operate on all tasks in schema {{ target.database }}.{{ schema }} to role {{ role }};
                    {% endset %}
                    {% set grant = run_query(grant_query) %}
                {%endif%}
            {% endfor %}
        {%endfor%}
    {% endif %}
{% endmacro %}
