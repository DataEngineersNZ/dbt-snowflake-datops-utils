{% macro grant_share_read(view_names, grant_shares, revoke_current_grants) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% if view_names | length > 0 %}
            {% set schemas = [] %}
            {% for item in view_names %}
                {% if item.split(".")[0] not in schemas %}
                    {{ schemas.append(item.split(".")[0]) }}
                {% endif %}
            {% endfor %}
            {% for schema in schemas %}
                {% set views = [] %}
                {% for item in view_names %}
                    {% if item.split(".")[0] == schema %}
                        {{ views.append(item.split(".")[1]) }}
                    {% endif %}
                {% endfor %}
                {% do dbt_dataengineers_utils.grant_share_read_specific_schema(schema, views, grant_shares, revoke_current_grants) %}
            {% endfor %}
        {% else %}
            {% if revoke_current_grants and execute %}
                {% set share_results = run_query("show shares;") %}
                {% set execute_statements = [] %}
                {% for share in share_results %}
                    {% if share.kind == 'OUTBOUND' %}
                        {% set share_desc = run_query("desc share " ~ share.name | lower  ~ ";") %}
                        {% for row in share_desc %}
                            {% if row[0] not in ["DATABASE"] %}
                                {% if row[1].split(".")[0] | lower == target.database | lower %}
                                    {% if row[0] == "SCHEMA" %}
                                        {{ execute_statements.append("revoke usage on " ~  row[0] | lower ~ " " ~ row[1] | lower ~ " from share " ~ share.name ~ ";") }}
                                    {% else %}
                                        {{ execute_statements.append("revoke select on " ~  row[0] | lower ~ " " ~ row[1] | lower ~ " from share " ~ share.name ~ ";") }}
                                    {% endif %}
                                {% endif %}
                            {% endif %}
                        {% endfor %}
                    {% endif %}
                {% endfor %}
                {% for statement in execute_statements %}
                    {% do log(statement, info=True) %}
                    {% set grant = run_query(statement) %}
                {% endfor %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}



{% macro grant_share_read_specific_schema(schema_name, view_names, grant_shares, revoke_current_grants) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set execute_statements = [] %}
        {% set snowflake_shares = [] %}
        {% if execute %}
            {% set share_results = run_query("show shares;") %}
            {% set current_account = run_query("select current_account();")%}
            {% for share in share_results %}
                {% if share.kind == 'OUTBOUND' %}
                    {% if share.name not in snowflake_shares %}
                        {{ snowflake_shares.append(share.name) }}
                    {% endif %}
                {% endif %}
            {% endfor %}
            {% do log("====> Processing Schema Share Reads for " ~ schema_name | lower, info=True) %}
            {% if revoke_current_grants %}
                {% set results = run_query("show grants on schema " ~ target.database | lower ~ "." ~ schema_name | lower ~ ";") %}
                {% for row in results %}
                    {% if row.privilege in ["USAGE"] and row.granted_to in ["SHARE"] %}
                        {% if row.grantee_name.replace(current_account[0][0] ~ ".","") not in grant_shares %}
                            {% if row.grantee_name in snowflake_shares %}
                                {{ execute_statements.append("revoke " ~ row.privilege | lower  ~ " on schema " ~ target.database ~ "." ~ schema_name | lower ~ " from share " ~ row.grantee_name | lower ~ ";") }}
                            {% endif %}
                        {%endif%}
                    {%endif%}
                {% endfor %}
                {% for share in snowflake_shares %}
                    {% do log("====> Processing Share Reads for " ~ share | lower, info=True) %}
                    {% set share_desc = run_query("desc share " ~ share | lower  ~ ";") %}
                    {% for row in share_desc %}
                        {% if row[0] not in ["DATABASE", "SCHEMA"] %}
                            {% if row[1].split(".")[0] | lower == target.database | lower %}
                                {% if row[1].split(".")[1] | lower == schema_name | lower %}
                                    {% if share not in grant_shares or row[1].split(".")[2] |lower not in view_names  %}
                                        {{ execute_statements.append("revoke select on " ~  row[0] ~ " " ~ row[1] ~ " from share " ~ share ~ ";") }}
                                    {% endif %}
                                {% endif %}
                            {% endif %}
                        {% endif %}
                    {% endfor %}
                {% endfor %}

            {% endif %}
            {% for share in grant_shares %}
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