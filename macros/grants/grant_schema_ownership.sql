{% macro grant_schema_ownership(exclude_schemas, role_name) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% if execute %}
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
                {% if include_schemas | length > 0%}
                    {% set formatted_parts = [] %}
                    {% for schema in schema_list %}
                        {{ formatted_parts.append("'" ~ schema ~ "'") }}
                    {% endfor %}
                    {% set formatted_schema_list = formatted_parts | join(', ') %}

                    {% set queries = [] %}
                    {% do log("Verifying Ownership rights on schemas in " ~ target.database ~ " for " ~ role_name, info=True) %}
                    {{ queries.extend(dbt_dataengineers_utils.get_grant_schema_ownership_sql(formatted_schema_list, role_name)) }}
                    {% do log("Verifying Ownership rights on models in " ~ target.database ~ " for " ~ role_name, info=True) %}
                    {{ queries.extend(dbt_dataengineers_utils.get_grant_model_ownership_sql(formatted_schema_list, role_name)) }}
                    {% do log("Verifying Ownership rights on tasks in " ~ target.database ~ " for " ~ role_name, info=True) %}
                    {{ queries.extend(dbt_dataengineers_utils.get_grant_task_ownership_sql(formatted_schema_list, role_name)) }}
                    {% do log("Verifying Ownership rights on functions in " ~ target.database ~ " for " ~ role_name, info=True) %}
                    {{ queries.extend(dbt_dataengineers_utils.get_grant_functions_ownership_sql(formatted_schema_list, role_name)) }}
                    {% do log("Verifying Ownership rights on procedures in " ~ target.database ~ " for " ~ role_name, info=True) %}
                    {{ queries.extend(dbt_dataengineers_utils.get_grant_procedure_ownership_sql(formatted_schema_list, role_name)) }}
                    {% do log("Verifying Ownership rights on streams in " ~ target.database ~ " for " ~ role_name, info=True) %}
                    {{ queries.extend(dbt_dataengineers_utils.get_grant_stream_ownership_sql(formatted_schema_list, role_name)) }}
                    {% do log("Verifying Ownership rights on network rules in " ~ target.database ~ " for " ~ role_name, info=True) %}
                    {{ queries.extend(dbt_dataengineers_utils.get_grant_network_rule_ownership_sql(formatted_schema_list, role_name)) }}

                    {% do log("Verifying Ownership rights on stages, file formats and sequences in " ~ target.database ~ " for " ~ role_name, info=True) %}
                    {{ queries.extend(dbt_dataengineers_utils.get_grant_other_ownership_sql(formatted_schema_list, role_name)) }}

                    {% for query in queries %}
                        {% set grant = run_query(query) %}
                    {% endfor %}
                {% endif %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}

















{% macro get_grant_object_ownership_sql(schema_name, object_type, role_name) %}
    {% set query %}
        select distinct
            privilege,
            granted_on,
            case
                when granted_on = 'PROCEDURE' then replace(split(name, ':')[0], '()', '')
                when granted_on = 'FUNCTION' then replace(split(name, ':')[0], '()', '')
                else name
            end as object_name,
            case
                when granted_on = 'PROCEDURE' then split(name, ':')[1]
                when granted_on = 'FUNCTION' then split(name, ':')[1]
                else ''
            end as arguments,
            grantee_name
        from snowflake.account_usage.grants_to_roles
        where table_schema = '{{ schema_name }}'
        and table_catalog = '{{ target.database }}'
        and privilege = 'OWNERSHIP'
        and granted_on = '{{ object_type }}'
        and grantee_name != '{{ role_name | upper }}'
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if grant_roles | length > 0 %}
        {% for result in results %}
            {% if object_type in ["PROCEDURE", "FUNCTION"] %}
                {{ statements.append(" grant ownership on " ~ object_type | lower  ~ target.database ~ "." ~ schema ~ "." ~ result.object_name ~ "(" ~ result.arguments ~ ")" ~ " to role " ~ role_name ~ " revoke current grants;") }}
            {% else %}
                {{ statements.append(" grant ownership on " ~ object_type | lower  ~ target.database ~ "." ~ schema ~ "." ~ result.object_name ~ " to role " ~ role_name ~ " revoke current grants;") }}
            {% endif %}
        {% endfor %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}
