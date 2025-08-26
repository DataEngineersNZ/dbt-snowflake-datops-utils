{% macro grant_usage_to_application(object_type, prefix, grant_applications) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set revoke_statements = [] %}
        {% set grant_statements = [] %}
        {% set grant_schemas = [] %}
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
            {% if object[1] not in grant_schemas %}
                {{ grant_schemas.append(object[1]) }}
            {% endif %}
            {% set query %}
                show grants on {{ object_type }} {{ target.database }}.{{ object[2] }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege not in ["OWNERSHIP", "SELECT", "REFERENCES", "REBUILD"] %}
                        {% if row.privilege in grant_types %}
                            {% if row.grantee_name not in grant_applications %}
                                {{ revoke_statements.append({ "privilege" : row.privilege, "role" : row.grantee_name, "schema" : object[1], "object" : object[2] }) }}
                            {% else %}
                                {{ existing_grants.append({ "privilege" : row.privilege, "role" : row.grantee_name, "schema" : object[1], "object" : object[2] }) }}
                            {%endif%}
                        {% else %}
                            {{ revoke_statements.append({ "privilege" : row.privilege, "role" : row.grantee_name, "schema" : object[1], "object" : object[2] }) }}
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
                            {{ grant_statements.append({ "privilege" : privilege, "role" : application, "schema" : object[1], "object" : object[2] }) }}
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

        {% do dbt_dataengineers_utils.grant_database_usage_to_application(grant_applications, target.database) %}
        {% do dbt_dataengineers_utils.grant_schema_usage_to_application(grant_applications, target.database, grant_schemas) %}
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

{% macro grant_database_usage_to_application(grant_applications, target_database) %}
    {% set existing_database_usage = [] %}
    {% set execute_statements = [] %}
    {% set matching_objects %}
        show grants on database {{ target_database }}
        ->>
        select
        "name" as database_name,
        "grantee_name" as application_name
        from $1
        where "privilege" = 'USAGE'
        and "granted_to" = 'APPLICATION';
    {% endset %}
    {% set objects = run_query(matching_objects) %}
    {% for object in objects %}
        {{ existing_database_usage.append(object[1]) }}
    {% endfor %}
    {% for application_name in grant_applications %}
        {% if application_name not in existing_database_usage %}
            {{ execute_statements.append("grant usage on database " ~ target_database ~ " to application " ~ application_name ~ ";") }}
        {% endif %}
    {% endfor %}
    {% if execute_statements | length > 0 %}
        {% do log("Executing usage grants for applications on database ...", info=True) %}
        {% for statement in execute_statements %}
            {% do log(statement, info=True) %}
            {% set grant = run_query(statement) %}
        {% endfor %}
        {% do log("Usage grants executed successfully for applications.", info=True) %}
    {% else %}
        {% do log("No usage grants to execute for applications.", info=True) %}
    {% endif %}
{% endmacro %}

{% macro grant_schema_usage_to_application(grant_applications, target_database, schemas) %}
    {% set existing_schema_usage = [] %}
    {% set execute_statements = [] %}
    {% for schema in schemas %}
        {% set matching_objects %}
            show grants on schema {{ target_database }}.{{ schema }}
            ->>
            select
            "name" as schema_name,
            "grantee_name" as application_name
            from $1
            where "privilege" = 'USAGE'
            and "granted_to" = 'APPLICATION';
        {% endset %}
        {% set objects = run_query(matching_objects) %}
        {% for object in objects %}
            {{ existing_schema_usage.append(object[1]) }}
        {% endfor %}
        {% for application_name in grant_applications %}
            {% if application_name not in existing_schema_usage %}
                {{ execute_statements.append("grant usage on schema " ~ target_database ~ "." ~ schema ~ " to application " ~ application_name ~ ";") }}
            {% endif %}
        {% endfor %}
    {% endfor %}
    {% if execute_statements | length > 0 %}
        {% do log("Executing usage grants for applications on schemas ...", info=True) %}
        {% for statement in execute_statements %}
            {% do log(statement, info=True) %}
            {% set grant = run_query(statement) %}
        {% endfor %}
        {% do log("Usage grants executed successfully for applications.", info=True) %}
    {% else %}
        {% do log("No usage grants to execute for applications.", info=True) %}
    {% endif %}
{% endmacro %}