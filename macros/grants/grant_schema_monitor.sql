{% macro grant_schema_monitor(exclude_schemas, grant_roles) %}
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
                {% do grant_schema_monitor_specific(include_schemas, grant_roles, true) %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}

{% macro grant_schema_monitor_specific(schemas, grant_roles, revoke_current_grants) %}
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
                where privilege_type in ('MONITOR')
                and object_schema = '{{ schema }}'
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row[2] in ["MONITOR"] %}
                        {% if row.grantee_name not in grant_roles %}
                            {% if revoke_current_grants %}
                                {% do log("Revoking Monitor Grants from schema " ~ schema ~ " from role " ~ row.grantee_name, info=True) %}
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
                    {% do log("Adding Monitor Grants (for task and pipes) from schema " ~ schema ~ " from role " ~ row.grantee_name, info=True) %}
                    {% set grant_query %}
                        grant usage on schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant monitor on all pipes in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant monitor on all tasks in schema {{ target.database }}.{{ schema }} to role {{ role }};
                    {% endset %}
                    {% set grant = run_query(grant_query) %}
                {%endif%}
            {% endfor %}
        {%endfor%}
    {% endif %}
{% endmacro %}
