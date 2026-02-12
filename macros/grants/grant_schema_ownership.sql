{% macro grant_schema_ownership(exclude_schemas, role_name) %}
    {# Maintain signature & invocation semantics; use helpers for clarity and efficiency #}
    {% if flags.WHICH not in ['run', 'run-operation'] %}
        {% do log('Skipping grant_schema_ownership: not run/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_schema_ownership: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if exclude_schemas is not iterable %}
        {% set exclude_schemas = [] %}
    {% endif %}
    {% if 'INFORMATION_SCHEMA' not in exclude_schemas %}
        {% do exclude_schemas.append('INFORMATION_SCHEMA') %}
    {% endif %}

    {% set include_schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas) %}
    {% if include_schemas | length == 0 %}
        {% do log('No schemas eligible for ownership processing in ' ~ target.database, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set formatted_schema_list = dbt_dataengineers_utils._grants_format_list(include_schemas) %}
    {% set queries = [] %}
    {% do log('Verifying Ownership rights across ' ~ (include_schemas | length) ~ ' schemas in ' ~ target.database ~ ' for role ' ~ role_name, info=True) %}

    {% do queries.extend(dbt_dataengineers_utils.get_grant_schema_ownership_sql(formatted_schema_list, role_name)) %}
    {% do queries.extend(dbt_dataengineers_utils.get_grant_model_ownership_sql(formatted_schema_list, role_name)) %}
    {% do queries.extend(dbt_dataengineers_utils.get_grant_task_ownership_sql(formatted_schema_list, role_name)) %}
    {% do queries.extend(dbt_dataengineers_utils.get_grant_functions_ownership_sql(formatted_schema_list, role_name)) %}
    {% do queries.extend(dbt_dataengineers_utils.get_grant_procedure_ownership_sql(formatted_schema_list, role_name)) %}
    {% do queries.extend(dbt_dataengineers_utils.get_grant_stream_ownership_sql(formatted_schema_list, role_name)) %}
    {% do queries.extend(dbt_dataengineers_utils.get_grant_network_rule_ownership_sql(formatted_schema_list, role_name)) %}
    {% do queries.extend(dbt_dataengineers_utils.get_grant_other_ownership_sql(formatted_schema_list, role_name)) %}

    {% if queries | length == 0 %}
        {% do log('No ownership grant statements generated (all objects already owned by ' ~ role_name ~ ')', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('Executing ' ~ (queries | length) ~ ' ownership grant statements for role ' ~ role_name, info=True) %}
    {% for q in queries %}
        {% if q %}
            {% set _ = run_query(q) %}
        {% endif %}
    {% endfor %}
    {% do log('Completed ownership grants for role ' ~ role_name, info=True) %}
    {% do return(none) %}
{% endmacro %}
