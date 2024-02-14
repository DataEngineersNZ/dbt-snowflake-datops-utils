{% macro grant_schema_ownership_access(exclude_schemas, role_name) %}
    {% if "INFORMATION_SCHEMA" not in exclude_schemas %}
        {{ exclude_schemas.append("INFORMATION_SCHEMA") }}
    {% endif %}
    {% if flags.WHICH in ['run'] %}
        {% set query %}
            show schemas in database {{ target.database }};
        {% endset %}
        {% set results = run_query(query) %}
        {% if execute %}
            {% for row in results %}
                {% set schema = row.name %}
                {% set include_schemas = [] %}
                {% if schema not in exclude_schemas %}
                    {{ include_schemas.append(schema) }}
                {% endif %}
            {% endfor %}
            {% if include_schemas | length > 0%}
                {% for schema in include_schemas %}
                    {% set grant_query %}
                        grant usage on schema {{ target.database }}.{{ schema }} to role {{ role_name }};
                        grant ownership on schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all views in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all materialized views in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all tables in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all external tables in {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all dynamic tables in {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all stages in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all file formats in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all functions in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all sequences in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all procedures in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all streams in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all tasks in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                        grant ownership on all masking policies in schema {{ target.database }}.{{ schema }} to role {{ role_name }} revoke current grants;
                    {% endset %}
                    {% set grant = run_query(grant_query) %}
                {% endfor %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}
