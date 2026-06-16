{% macro grant_operate_to_application(prefix, grant_applications) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set revoke_statements = [] %}
        {% set grant_statements = [] %}
        {% set grant_schemas = [] %}
        {% set execute_statements = [] %}
        {% set grant_types = ["OPERATE"] %}
        {% set matching_objects %}
            show tasks in database {{ target.database }}
            ->>
            select
            "name" as object_name,
            "schema_name" as schema_name,
            concat("schema_name", '.', "name") as object_signature
            from $1
            where startswith(lower("name"), {{ "'" ~ prefix | lower ~ "'" }});
        {% endset %}
        {% set objects = run_query(matching_objects) %}

        {% for object in objects %}
            {% set existing_grants = [] %}
            {% if object[1] not in grant_schemas %}
                {% do grant_schemas.append(object[1]) %}
            {% endif %}
            {% set query %}
                show grants on task {{ target.database }}.{{ object[2] }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege not in ["OWNERSHIP"] %}
                        {% if row.privilege in grant_types %}
                            {% if row.grantee_name not in grant_applications %}
                                {% do revoke_statements.append({ "privilege" : row.privilege, "role" : row.grantee_name, "schema" : object[1], "object" : object[2] }) %}
                            {% else %}
                                {% do existing_grants.append({ "privilege" : row.privilege, "role" : row.grantee_name, "schema" : object[1], "object" : object[2] }) %}
                            {%endif%}
                        {% else %}
                            {% do revoke_statements.append({ "privilege" : row.privilege, "role" : row.grantee_name, "schema" : object[1], "object" : object[2] }) %}
                        {%endif%}
                    {% endif %}
                {% endfor %}

                {% for application in grant_applications %}
                    {% set existing_role_grants = [] %}
                    {% for existing_grant in existing_grants %}
                        {% if existing_grant.role == application %}
                            {% do existing_role_grants.append(existing_grant.privilege) %}
                        {% endif %}
                    {% endfor %}
                    {% for privilege in grant_types %}
                        {% if privilege not in existing_role_grants %}
                            {% do grant_statements.append({ "privilege" : privilege, "role" : application, "schema" : object[1], "object" : object[2] }) %}
                        {% endif %}
                    {% endfor %}
                {% endfor %}
            {%endif%}
        {%endfor%}
        {% for stm in revoke_statements %}
            {% do execute_statements.append("revoke " ~ stm.privilege ~ " on task " ~ target.database ~ "." ~ stm.object ~ " from application " ~ stm.role ~ ";") %}
        {% endfor %}
        {% for stm in grant_statements %}
            {% do execute_statements.append("grant " ~ stm.privilege ~ " on task " ~ target.database ~ "." ~ stm.object ~ " to application " ~ stm.role ~ ";") %}
        {% endfor %}

        {% do dbt_dataengineers_utils.grant_database_usage_to_application(grant_applications, target.database) %}
        {% do dbt_dataengineers_utils.grant_schema_usage_to_application(grant_applications, target.database, grant_schemas) %}
        {% if execute_statements | length > 0 %}
            {% do log("Executing privilege grants and revokes for tasks...", info=True) %}
            {% for statement in execute_statements %}
                {% do log(statement, info=True) %}
                {% set grant = run_query(statement) %}
            {% endfor %}
            {% do log("Privilege grants and revokes executed successfully for tasks.", info=True) %}
        {% else %}
            {% do log("No privilege grants or revokes to execute for tasks.", info=True) %}
        {% endif %}
    {% endif %}
{% endmacro %}
