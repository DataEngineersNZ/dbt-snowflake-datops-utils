{% macro grant_schema_read(exclude_schemas, grant_roles, include_future_grants) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% if "INFORMATION_SCHEMA" not in exclude_schemas %}
            {{ exclude_schemas.append("INFORMATION_SCHEMA") }}
        {% endif %}
        {% set include_schemas = [] %}
        {% set query %}
            show schemas in database {{ target.database }};
        {% endset %}
        {% set results = run_query(query) %}
        {% if execute %}
            {% for row in results %}
                {% if row.name not in exclude_schemas %}
                    {{ include_schemas.append(row.name) }}
                {% endif %}
            {% endfor %}

            {% if include_schemas | length > 0 %}
                {% do dbt_dataengineers_utils.grant_schema_read_specific(include_schemas, grant_roles, include_future_grants, true) %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}

{% macro grant_schema_read_specific(schemas, grant_roles, include_future_grants, revoke_current_grants) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set existing_roles = [] %}
        {% for schema in schemas %}
            {% do log("Checking usage grants for schema " ~ schema | lower, info=True) %}
            {% set query %}
                show grants on schema {{ target.database }}.{{ schema }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege in ["USAGE"] %}
                        {% if row.grantee_name not in grant_roles %}
                            {% if revoke_current_grants %}
                                {% set revoke_query %}
revoke {{ row.privilege | lower }} on schema {{ target.database | lower }}.{{ schema | lower }} from role {{ row.grantee_name | lower }};
                                {% endset %}
                                {% do log(revoke_query, info=True) %}
                                {% set revoke = run_query(revoke_query) %}
                            {% endif %}
                        {%else%}
                            {% if row.grantee_name not in existing_roles %}
                                {{ existing_roles.append(row.grantee_name) }}
                            {% endif %}
                        {%endif%}
                    {%endif%}
                {% endfor %}
            {% endif %}
            {% if grant_roles | length == 0 %}
                {% do log("Checking read grants to revoke for all objects in schema  " ~ schema | lower, info=True) %}
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
                {% if execute %}
                    {% for row in results %}
                        {% if row[2] in ["SELECT", "REFERENCES", "REBUILD"] %}
                            {% if revoke_current_grants %}
                                {% set revoke_query %}
revoke {{ row[2] | lower }} on all {{ row[0] | lower }}s in schema {{ target.database | lower }}.{{ row[1] | lower }} from role {{ row[3] | lower }};
                                {% endset %}
                                {% do log(revoke_query, info=True) %}
                                {% set revoke = run_query(revoke_query) %}
                            {% endif %}
                        {% endif %}
                    {% endfor %}
                {% endif %}
            {% else %}
                {% do log("Checking read Grants for objects in schema  " ~ schema | lower, info=True) %}
                {% set query %}
                    select
                        case
                            when table_type = 'BASE TABLE' then 'TABLE'
                            when table_type is null then 'DYNAMIC TABLE'
                            else tables.table_type
                        end as object_type
                        , concat(tables.table_schema, '.', tables.table_name) as object_name
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
                {% if execute %}
                    {% for row in results %}
                        {% if row[2] in ["SELECT", "REFERENCES", "REBUILD"] %}
                            {% if row[3] not in grant_roles %}
                                {% if revoke_current_grants %}
                                    {% set revoke_query %}
revoke {{ row[2] | lower }} on {{ row[0] | lower }} {{ target.database |lower }}.{{ row[1] | lower }} from role {{ row[3] | lower }};
                                    {% endset %}
                                    {% do log(revoke_query, info=True) %}
                                    {% set revoke = run_query(revoke_query) %}
                                {% endif %}
                            {% else %}
                                {% if row[3] not in existing_roles %}
                                    {{ existing_roles.append(row[3]) }}
                                {% endif %}
                            {%endif%}
                        {%endif%}
                    {% endfor %}
                {% endif %}
            {% endif %}
            {% for role in grant_roles %}
                {% if role not in existing_roles %}
                    {% set queries = [] %}
                    {{ queries.append(" grant usage on schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ queries.append(" grant select on all views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ queries.append(" grant select on all materialized views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ queries.append(" grant select on all tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ queries.append(" grant rebuild on all tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ queries.append(" grant references on all tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ queries.append(" grant select on all external tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ queries.append(" grant select on all dynamic tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {{ queries.append(" grant select on all streams in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                    {% for query in queries %}
                        {% do log(query, info=True) %}
                        {% set grant = run_query(query) %}
                    {% endfor %}
                    {% if include_future_grants %}
                        {% set future_queries = [] %}
                        {{ future_queries.append(" grant select on future views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ future_queries.append(" grant select on future materialized views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ future_queries.append(" grant select on future tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ future_queries.append(" grant rebuild on future tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ future_queries.append(" grant references on future tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ future_queries.append(" grant select on future external tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ future_queries.append(" grant select on future dynamic tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {{ future_queries.append(" grant select on future streams in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role ~ ";") }}
                        {% for query in queries %}
                            {% do log(query, info=True) %}
                            {% set grant = future_queries(query) %}
                        {% endfor %}
                    {% endif %}
                {%endif%}
            {% endfor %}
        {%endfor%}
    {% endif %}
{% endmacro %}