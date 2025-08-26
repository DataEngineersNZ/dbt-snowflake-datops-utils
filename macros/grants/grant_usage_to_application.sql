{% macro grant_usage_to_application(object_type, prefix, grant_applications) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set revoke_statements = [] %}
        {% set grant_statements = [] %}
        {% set execute_statements = [] %}
        {% set grant_types = ["USAGE"] %}
        {% set matching_objects %}
            show {{ object_type }}s in database {{ target.database }}
            ->>
            select
            "name" as object_name,
            "schema_name" as schema_name,
            concat("schema_name", '.', trim(split("arguments", 'RETURN')[0]::string)) as object_signature
            from $1
            where "is_builtin" = 'N' and startswith(lower("name"), {{ "'" ~ prefix | lower ~ "'" }});
        {% endset %}
        {% set objects = run_query(matching_objects) %}

        {% for object in objects %}
            {% set existing_grants = [] %}
            {% set query %}
                show grants on {{ object_type }} {{ target.database }}.{{ object[2] }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege not in ["OWNERSHIP", "SELECT", "REFERENCES", "REBUILD"] %}
                        {% if row.privilege in grant_types %}
                            {% if row.grantee_name not in grant_applications %}
                                {{ revoke_statements.append({ "privilege" : row.privilege, "role" : row.grantee_name, "object" : object[2] }) }}
                            {% else %}
                                {{ existing_grants.append({ "privilege" : row.privilege, "role" : row.grantee_name, "object" : object[2] }) }}
                            {%endif%}
                        {% else %}
                            {{ revoke_statements.append({ "privilege" : row.privilege, "role" : row.grantee_name, "object" : object[2] }) }}
                        {%endif%}
                    {% endif %}
                {% endfor %}

                {% for application in grant_applications %}
                    {% set existing_role_grants = [] %}
                    {% for existing_grant in existing_grants %}
                        {% if existing_grant.role == application %}
                            {{ existing_role_grants.append(existing_grant.privilege) }}
                        {% endif %}
                    {% endfor %}
                    {% for privilege in grant_types %}
                        {% if privilege not in existing_role_grants %}
                            {{ grant_statements.append({ "privilege" : privilege, "role" : application, "object" : object[2] }) }}
                        {% endif %}
                    {% endfor %}
                {% endfor %}
            {%endif%}
        {%endfor%}
        {% for stm in revoke_statements %}
            {{ execute_statements.append("revoke " ~ stm.privilege ~ " on " ~ object_type ~ " " ~ target.database ~ "." ~ stm.object ~ " from application " ~ stm.role ~ ";") }}
        {% endfor %}
        {% for stm in grant_statements %}
            {{ execute_statements.append("grant " ~ stm.privilege ~ " on " ~ object_type ~ " " ~ target.database ~ "." ~ stm.object ~ " to application " ~ stm.role ~ ";") }}
        {% endfor %}
        {% if execute_statements | length > 0 %}
            {% do log("Executing privilege grants and revokes for " ~ object_type ~"s...", info=True) %}
            {% for statement in execute_statements %}
                {% do log(statement, info=True) %}
                {% set grant = run_query(statement) %}
            {% endfor %}
            {% do log("Privilege grants and revokes executed successfully for " ~ object_type ~ "s.", info=True) %}
        {% else %}
            {% do log("No privilege grants or revokes to execute for " ~ object_type ~ "s.", info=True) %}
        {% endif %}
    {% endif %}
{% endmacro %}