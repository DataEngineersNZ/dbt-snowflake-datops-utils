{% macro grant_share_views(schema_name, view_names, grant_shares, revoke_current_grants) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set execute_statements = [] %}
        {% set snowflake_shares = [] %}
        {% if execute %}
            {% set share_results = run_query("show shares;") %}
            {% for share in share_results %}
                {% if share.kind == 'OUTBOUND' %}
                    {% if share.name not in snowflake_shares %}
                        {{ snowflake_shares.append(share.name) }}
                    {% endif %}
                {% endif %}
            {% endfor %}
            {% do log("====> Processing Schema Reads for " ~ views.split(".")[0] | lower, info=True) %}
            {% set results = run_query("show grants on schema " ~ target.database | lower ~ "." ~ schema_name| lower ~ ";") %}
            {% for row in results %}
                {% if row.privilege in ["USAGE"] and row.granted_to in ["SHARE"] %}
                    {% if row.grantee_name not in grant_shares %}
                        {% if revoke_current_grants %}
                            {% if row.grantee_name in snowflake_shares %}
                                {{ execute_statements.append("revoke " ~ row.privilege | lower  ~ " on schema " ~ target.database ~ "." ~ views.split(".")[0] | lower ~ " from share " ~ row.grantee_name | lower ~ ";") }}
                            {% endif %}
                        {% endif %}
                    {%endif%}
                 {%endif%}
            {% endfor %}
            {% for share in grant_shares %}
                {% set share_desc = run_query("desc share " ~ share | lower  ~ ";") %}
                {% for row in share_desc %}
                    {% if row[0] not in ["DATABASE", "SCHEMA"] %}
                        {% if row[1].split(".")[0] == schema_name %}
                            {% if revoke_current_grants %}
                                {% if row[1].split(".")[1] not in view_names %}
                                    {{ execute_statements.append("revoke usage on " ~  row[0] ~ " " ~ target.database ~ " from share " ~ share ~ ";") }}
                                {% endif %}
                            {% endif %} 
                        {% endif %}
                    {% endif %}
                {% endfor %}
                {{ execute_statements.append("grant usage on schema " ~ target.database ~ "." ~ schema_name ~ " to share " ~ share ~ ";") }}
                {% for view in view_names %}
                    {{ execute_statements.append("grant select on view " ~ target.database ~ "." ~ schema_name ~ "." ~ view ~ " to share " ~ share ~ ";") }}
                {% endfor %}
            {% endfor %}
            {% for statement in execute_statements %}
                {% do log(statement, info=True) %}
                {% set grant = run_query(statement) %}
            {% endfor %}
        {% endif %}
    {% endif %}
{% endmacro %}