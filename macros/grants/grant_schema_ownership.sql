{% macro grant_schema_ownership(exclude_schemas, role_name) %}
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
            {% if include_schemas | length > 0%}
                {% for schema in include_schemas %}
                    {% set queries = [] %}
                    {% do log("Adding Ownership rights on " ~ target.database ~ "." ~ schema ~ " for " ~ role_name, info=True) %}
                    {{ queries.append(" grant ownership on schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all materialized views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all external tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all dynamic tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all stages in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all file formats in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all functions in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all sequences in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all procedures in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all streams in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all tasks in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {{ queries.append(" grant ownership on all network rules in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ " revoke current grants;") }}
                    {% for query in queries %}
                        {% set grant = run_query(query) %}
                    {% endfor %}
                {% endfor %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}