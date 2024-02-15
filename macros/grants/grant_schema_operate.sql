{% macro grant_schema_operate(exclude_schemas, grant_roles) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% if "INFORMATION_SCHEMA" not in exclude_schemas %}
            {{ exclude_schemas.append("INFORMATION_SCHEMA") }}
        {% endif %}
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
            {% if include_schemas | length > 0 %}
                {% do grant_schema_operate_access_specific(include_schemas, grant_roles, true) %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}

{% macro grant_schema_operate_specific(schemas, grant_roles, revoke_current_grants) %}
    {% if flags.WHICH in ['run'] %}
       {% set existing_roles = []%}
       {% for schema in schemas %}
            {% set query %}
                select
                    object_type
                    , concat(object_schema, '.', object_name) as object_name
                    , privilege_type as privilege
                    , grantee as grantee_name
                from information_schema.object_privileges
                where privilege_type in ('OPERATE')
                and object_schema = '{{ schema }}'
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row[2] in ["OPERATE"] %}
                        {% if row.grantee_name not in grant_roles %}
                            {% if revoke_current_grants %}
                                {% do log("Revoking operate Grants from schema " ~ schema ~ " from role " ~ row.grantee_name, info=True) %}
                                {% set revoke_query %}
                                    revoke {{ row[2] }} on {{ row[0] }} in schema {{ target.database }}.{{ row[1] }} from role {{ row[3] }};
                                {% endset %}
                                {% set revoke = run_query(revoke_query) %}
                            {% endif %}
                        {%else%}
                            {{ existing_roles.append(row[3]) }}
                        {%endif%}
                    {%endif%}
                {% endfor %}
            {%endif%}
            {% for role in grant_roles %}
                {% if role not in existing_roles %}
                    {% do log("Adding operate Grants (for task and pipes) from schema " ~ schema ~ " from role " ~ row.grantee_name, info=True) %}
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
