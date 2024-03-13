{% macro grant_share_views(view_names, share_names, revoke_current_grants) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set execute_statements = [] %}
        {% set snowflake_shares = [] %}
        {% set query_shares %}
            show shares
        {% endset %}
        {% set share_results = run_query(query_shares) %}
        {% for share in share_results %}
            {% if share.name not in snowflake_shares %}
                {{ snowflake_shares.append(share.name) }}
            {% endif %}
        {% endfor %}
        {% for view in view_names %}
            {% do log("====> Processing Schema Reads for " ~ views.split(".")[0] | lower, info=True) %}
            {% set query %}
                show grants on schema {{ target.database }}.{{ views.split(".")[0] }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege in ["USAGE"] %}
                        {% if row.grantee_name not in grant_roles %}
                            {% if revoke_current_grants %}
                                {% if row.grantee_name in snowflake_shares %}
                                    {{ execute_statements.append("revoke " ~ row.privilege | lower  ~ " on schema " ~ target.database ~ "." ~ views.split(".")[0] | lower ~ " from share " ~ row.grantee_name | lower ~ ";") }}
                                {% endif %}
                            {% endif %}
                        {%endif%}
                    {%endif%}
                {% endfor %}
            {% endif %}
            {% set query %}
                select distinct
                    case
                        when table_type = 'BASE TABLE' then 'TABLE'
                        when table_type is null then 'DYNAMIC TABLE'
                        else tables.table_type
                    end as object_type
                    , tables.table_schema
                    , table_privileges.privilege_type as privilege
                    , table_privileges.grantee as grantee_name
                from information_schema.table_privileges
                inner join information_schema.tables
                    on table_privileges.table_name = tables.table_name
                    and table_privileges.table_schema = tables.table_schema
                    and table_privileges.table_catalog = tables.table_catalog
                where tables.table_schema = '{{ schema }}'
                and table_privileges.privilege_type in ('SELECT', 'REFERENCES', 'REBUILD')
            {% endset %}
            {% set results = run_query(query) %}
            {% if grant_roles | length == 0 %}
                {% if execute %}
                    {% for row in results %}
                        {% if row[2] in ["SELECT", "REFERENCES", "REBUILD"] %}
                            {% if revoke_current_grants %}
                                {% if row[3] in snowflake_shares %}
                                    {{ execute_statements.append("revoke " ~ row[2] | lower  ~ " on all " ~ row[0] | lower ~ "s in schema " ~ target.database ~ "." ~ row[1] | lower ~ " from grant " ~ row[3] | lower ~ ";") }}
                                {% endif %}
                            {% endif %}
                        {% endif %}
                    {% endfor %}
                {% endif %}
            {% else %}
                {% if execute %}
                    {% for row in results %}
                        {% if row[2] in ["SELECT", "REFERENCES", "REBUILD"] %}
                            {% if row[3] not in grant_roles %}
                                {% if revoke_current_grants %}
                                    {% if row[3] in snowflake_shares %}
                                        {{ execute_statements.append("revoke " ~ row[2] | lower  ~ " on all " ~ row[0] | lower ~ "s in schema " ~ target.database ~ "." ~ row[1] | lower ~ " from role " ~ row[3] | lower ~ ";") }}
                                    {% endif %}
                                {% endif %}
                            {%endif%}
                        {%endif%}
                    {% endfor %}
                {% endif %}
            {% endif %}
            {% for role in grant_roles %}
                    {{ execute_statements.append("grant usage on schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ execute_statements.append("grant select on all views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ execute_statements.append("grant select on all materialized views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ execute_statements.append("grant select on all tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ execute_statements.append("grant rebuild on all tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ execute_statements.append("grant references on all tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ execute_statements.append("grant select on all external tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ execute_statements.append("grant select on all dynamic tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ execute_statements.append("grant select on all streams in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {% if include_future_grants %}
                        {{ execute_statements.append("grant select on future views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ execute_statements.append("grant select on future materialized views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ execute_statements.append("grant select on future tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ execute_statements.append("grant rebuild on future tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ execute_statements.append("grant references on future tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ execute_statements.append("grant select on future external tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ execute_statements.append("grant select on future dynamic tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ execute_statements.append("grant select on future streams in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {% endif %}
            {% endfor %}
        {%endfor%}
        {% for statement in execute_statements %}
            {% do log(statement, info=True) %}
            {% set grant = run_query(statement) %}
        {% endfor %}
    {% endif %}
{% endmacro %}