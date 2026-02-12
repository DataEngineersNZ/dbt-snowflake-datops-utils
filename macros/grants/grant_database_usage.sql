{% macro grant_database_usage(grant_roles, grant_shares=[], revoke_current_grants=true) %}
   {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set existing_roles = []%}
        {% set existing_shares = []%}
        {% set statements = [] %}
        {% if execute %}
            {% do log("Granting and Revoking Database Usage Grants", info=True) %}
            {% if revoke_current_grants %}
                {% set results = run_query("show grants on database " ~ target.database | lower ~ ";") %}
                {% set current_account = run_query("select current_account();")%}
                {% for row in results %}
                    {% if row.privilege == "USAGE" and row.granted_to in ["ROLE"] %}
                        {% if row.grantee_name not in grant_roles %}
                            {% do statements.append("revoke usage on database "  ~ target.database | lower  ~ " from role " ~ row.grantee_name | lower  ~ ";") %}
                        {% else %}
                            {% do existing_roles.append(row.grantee_name) %}
                        {% endif %}
                    {% elif row.privilege == "USAGE" and row.granted_to in ["SHARE"] %}
                        {% if row.grantee_name.replace(current_account[0][0] ~ ".","")  not in grant_shares %}
                            {% do statements.append("revoke usage on database "  ~ target.database | lower  ~ " from share " ~ row.grantee_name | lower  ~ ";") %}
                        {% else %}
                            {% do existing_shares.append(row.grantee_name.replace(current_account[0][0] ~ ".","")) %}
                        {% endif %}
                    {% endif %}
                {% endfor %}
            {% endif %}
            {% for role in grant_roles %}
                {% if role not in existing_roles %}
                    {% do statements.append("grant usage on database "  ~ target.database | lower  ~ " to role " ~ role | lower  ~ ";") %}
                {%endif%}
            {% endfor %}
            {% for share in grant_shares %}
                {% if share not in existing_shares %}
                    {% do statements.append("grant usage on database "  ~ target.database | lower  ~ " to share " ~ share | lower  ~ ";") %}
                {%endif%}
            {% endfor %}
            {% for statement in statements %}
                {% do log(statement, info=True) %}
                {% do run_query(statement) %}
            {% endfor %}
        {% endif %}
    {% endif %}
{% endmacro %}