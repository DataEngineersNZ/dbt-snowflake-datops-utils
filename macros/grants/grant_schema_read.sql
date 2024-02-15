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
                {% do grant_schema_read_specific(include_schemas, grant_roles, include_future_grants, true) %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}

{% macro grant_schema_read_specific(schemas, grant_roles, include_future_grants, revoke_current_grants) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% set existing_roles = [] %}
        {% for schema in schemas %}
            {% do log("Checking `USGAE` Grants for schema " ~ schema, info=True) %}
            {% set query %}
                show grants on schema {{ target.database }}.{{ schema }};
            {% endset %}
            {% set results = run_query(query) %}
            {% if execute %}
                {% for row in results %}
                    {% if row.privilege in ["USAGE"] %}
                        {% if row.grantee_name not in grant_roles %}
                            {% if revoke_current_grants %}
                                {% do log("Revoking `" ~ row.privilege ~ "` schema " ~ schema, info=True) %}
                                {% set revoke_query %}
                                    revoke {{ row.privilege }} on schema {{ target.database }}.{{ schema }} from role {{ row.grantee_name }};
                                {% endset %}
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
            {% do log("Checking `SELECT` Grants for objects in schema  " ~ schema, info=True) %}
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
                                {% do log("Revoking `" ~ row[2] ~ "`  schema " ~ schema, info=True) %}
                                {% set revoke_query %}
                                    revoke {{ row[2] }} on {{ row[0] }} {{ target.database }}.{{ row[1] }} from role {{ row[3] }};
                                {% endset %}
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
            {% do log("Granting permissions for tables / views in schema " ~ schema, info=True) %}
            {% for role in grant_roles %}
                {% if role not in existing_roles %}
                    {% set grant_query %}
                        grant usage on schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant select on all views in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant select on all materialized views in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant select on all tables in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant rebuild on all tables in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant references on all tables in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant select on all external tables in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant select on all dynamic tables in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        grant select on all streams in schema {{ target.database }}.{{ schema }} to role {{ role }};
                    {% endset %}
                    {% set grant = run_query(grant_query) %}
                    {% if include_future_grants %}
                        {% set grant_query %}
                            grant usage on schema {{ target.database }}.{{ schema }} to role {{ role }};
                            grant select on future views in schema {{ target.database }}.{{ schema }} to role {{ role }};
                            grant select on future materialized views in schema {{ target.database }}.{{ schema }} to role {{ role }};
                            grant select on future tables in schema {{ target.database }}.{{ schema }} to role {{ role }};
                            grant select on future external tables in schema {{ target.database }}.{{ schema }} to role {{ role }};
                            grant select on future dynamic tables in schema {{ target.database }}.{{ schema }} to role {{ role }};
                            grant select on future streams in schema {{ target.database }}.{{ schema }} to role {{ role }};
                        {% endset %}
                        {% set grant = run_query(grant_query) %}
                    {% endif %}
                {%endif%}
            {% endfor %}
        {%endfor%}
    {% endif %}
{% endmacro %}
