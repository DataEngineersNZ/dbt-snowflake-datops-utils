{% macro grant_object(object_type, objects, grant_types, grant_roles) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set revoke_statements = [] %}
        {% set grant_statements = [] %}
        {% set existing_grants = [] %}

        {% for object in objects %}
            {% set query %}
                show grants on {{ object_type }} {{ target.database }}.{{ object }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege not in ["OWNERSHIP", "SELECT", "REFERENCES", "REBUILD"] %}
                        {% if row.privilege in grant_types %}
                            {% if row.grantee_name not in grant_roles %}
                                {{ revoke_statements.append({ "privilege" : row.privilege, "role" : row.grantee_name, "object" : object }) }}
                            {% else %}
                                {{ existing_grants.append({ "privilege" : row.privilege, "role" : row.grantee_name, "object" : object }) }}
                            {%endif%}
                        {% else %}
                            {{ revoke_statements.append({ "privilege" : row.privilege, "role" : row.grantee_name, "object" : object }) }}
                        {%endif%}
                    {% endif %}
                {% endfor %}
                {% for role in grant_roles %}
                    {% set existing_role_grants = [] %}
                    {% for existing_grant in existing_grants %}
                        {% if existing_grant.role == role %}
                            {{ existing_role_grants.append(existing_grant.privilege) }}
                        {% endif %}
                    {% endfor %}
                    {% for privilege in grant_types %}
                        {% if privilege not in existing_role_grants %}
                            {{ grant_statements.append({ "privilege" : privilege, "role" : role, "object" : object }) }}
                        {% endif %}
                    {% endfor %}
                {% endfor %}
            {%endif%}
        {%endfor%}
        {% for stm in revoke_statements %}
            {% do log("revoke " ~ stm.privilege ~ " on " ~ stm.object ~ " from role " ~ stm.role, info=True) %}
            {% set grant_query %}
                revoke {{ stm.privilege }} on {{ object_type }} {{ target.database }}.{{ stm.object }} from role {{ stm.role }};
            {% endset %}
            {% set grant = run_query(grant_query) %}
        {% endfor %}
        {% for stm in grant_statements %}
            {% do log("grant " ~ stm.privilege ~ " on " ~ stm.object ~ " from role " ~ stm.role, info=True) %}
            {% set grant_query %}
                grant {{ stm.privilege }} on {{ object_type }} {{ target.database }}.{{ stm.object }} to role {{ stm.role }};
            {% endset %}
            {% set grant = run_query(grant_query) %}
        {% endfor %}
    {% endif %}
{% endmacro %}