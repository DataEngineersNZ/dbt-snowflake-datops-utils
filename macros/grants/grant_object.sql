{% macro grant_object(object_type, objects, grant_types, grant_roles) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set revoke_statements = [] %}
        {% set grant_statements = [] %}
        {% set execute_statements = [] %}

        {% for object in objects %}
            {% set existing_grants = [] %} {# reset per object #}
            {% do log("====> Processing " ~ object_type ~ " for " ~ object ~ " with grants " ~ grant_types | join(", ") ~ " for roles " ~ grant_roles | join(", "), info=True) %}
            {% set query %}
                show grants on {{ object_type }} {{ target.database }}.{{ object }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege not in ["OWNERSHIP", "SELECT", "REFERENCES", "REBUILD"] %}
                        {% if row.privilege in grant_types %}
                            {% if row.grantee_name not in grant_roles %}
                                {{ revoke_statements.append({ "privilege": row.privilege, "role": row.grantee_name, "object": object }) }}
                            {% else %}
                                {# add only once per (role, privilege, object) #}
                                {% set exists = false %}
                                {% for eg in existing_grants %}
                                    {% if eg.role == row.grantee_name and eg.privilege == row.privilege and eg.object == object %}
                                        {% set exists = true %}
                                    {% endif %}
                                {% endfor %}
                                {% if not exists %}
                                    {{ existing_grants.append({ "privilege": row.privilege, "role": row.grantee_name, "object": object }) }}
                                {% endif %}
                            {% endif %}
                        {% else %}
                            {{ revoke_statements.append({ "privilege": row.privilege, "role": row.grantee_name, "object": object }) }}
                        {% endif %}
                    {% endif %}
                {% endfor %}

                {% for role in grant_roles %}
                    {% do log("====> Checking " ~ object_type ~ " for " ~ object ~ " with role " ~ role, info=True) %}
                    {% set existing_role_grants = [] %}
                    {% for existing_grant in existing_grants %}
                        {% if existing_grant.role == role and existing_grant.object == object %}
                            {% if existing_grant.privilege not in existing_role_grants %}
                                {{ existing_role_grants.append(existing_grant.privilege) }}
                            {% endif %}
                        {% endif %}
                    {% endfor %}
                    {% do log("====> Existing grants for role " ~ role ~ " on " ~ object ~ " : " ~ (existing_role_grants | join(", ")), info=True) %}
                    {% for privilege in grant_types %}
                        {% if privilege not in existing_role_grants %}
                            {{ grant_statements.append({ "privilege": privilege, "role": role, "object": object }) }}
                        {% endif %}
                    {% endfor %}
                {% endfor %}
            {% endif %}
        {% endfor %}
        {% for stm in revoke_statements %}
            {{ execute_statements.append("revoke " ~ stm.privilege ~ " on " ~ object_type ~ " " ~ target.database ~ "." ~ stm.object ~ " from role " ~ stm.role ~ ";") }}
        {% endfor %}
        {% for stm in grant_statements %}
            {{ execute_statements.append("grant " ~ stm.privilege ~ " on " ~ object_type ~ " " ~ target.database ~ "." ~ stm.object ~ " to role " ~ stm.role ~ ";") }}
        {% endfor %}
        {% if execute_statements | length > 0 %}
            {% do log("Executing privilege grants and revokes for " ~ object_type ~ "s...", info=True) %}
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