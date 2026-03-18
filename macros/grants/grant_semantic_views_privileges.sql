-- Macro: grant_semantic_views_privileges.sql
-- Description: Grants and revokes privileges for all semantic views in a given schema to specified roles and revokes from other roles.
-- Usage: {{ grant_semantic_views_privileges(schema_name, grant_roles) }}

{% macro grant_semantic_views_privileges(exclude_schemas, grant_roles, include_future_grants) %}
    {% if flags.WHICH not in ['run', 'run-operation'] %}
        {% do log('Skipping grant_semantic_views_privileges: not run/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_semantic_views_privileges: compile phase', info=True) %}
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
        {% do log('grant_semantic_views_privileges: no schemas to process', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% do log('grant_semantic_views_privileges: processing ' ~ (include_schemas | length) ~ ' schemas for roles ' ~ (grant_roles | join(', ')), info=True) %}
    {% do dbt_dataengineers_utils.grant_semantic_views_privileges_specific(include_schemas, grant_roles, include_future_grants, true) %}
{% endmacro %}

{% macro grant_semantic_views_privileges_specific(schema_name, grant_roles) %}
    {% if flags.WHICH not in ['run', 'run-operation'] %}
        {% do log('Skipping grant_schema_read_specific: not run/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_schema_read_specific: compile phase', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if schemas | length == 0 %}
        {% do log('grant_schema_read_specific: no schemas provided', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set snowflake_roles = dbt_dataengineers_utils._grants_collect_roles() %}

    {% set execute_statements = [] %}
    {% for schema in schemas %}
        {% do log('====> Processing schema read grants for ' ~ schema, info=True) %}
        -- Grant SELECT on all semantic views to specified roles
        {% for role in grant_roles %}
            {% do execute_statements.append('grant select on all semantic views in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role | lower ~ ';') %}
        {% endfor %}


        {% set views_query %}
            SELECT semantic_view_name
            FROM snowflake.account_usage.semantic_views
            WHERE semantic_view_schema_name = '{{ schema }}'
            AND semantic_view_database_name = '{{ target.database }}'
            AND deleted IS NULL
        {% endset %}

        {% set views = run_query(views_query) %}


        -- Revoke SELECT only from roles that currently have it
        {% for view in views %}
            {% set grants_query %}
            SHOW GRANTS ON VIEW {{ target.database }}.{{ schema }}.{{ view['semantic_view_name'] }}
            {% endset %}
            {% set grants = run_query(grants_query) %}
            {% for role in revoke_roles %}
            {% for grant in grants %}
                {% if grant['privilege'] == 'SELECT' and grant['grantee'] == role %}
                {% do execute_statements.append("revoke select on semantic view " ~ target.database ~ "." ~ schema ~ "." ~ view['semantic_view_name'] ~ " from role " ~ role | lower ~ ";") %}
                {% endif %}
            {% endfor %}
            {% endfor %}
        {% endfor %}

    -- Execute all statements
        {% set total_statements = execute_statements | length %}
        {% if total_statements == 0 %}
            {% do log('grant_semantic_views_privileges: no changes required', info=True) %}
            {% do return(none) %}
        {% endif %}
        {% do log('grant_semantic_views_privileges: executing ' ~ total_statements ~ ' statements across ' ~ (schemas | length) ~ ' schemas', info=True) %}
        {% for stmt in execute_statements %}
            {% do log(stmt, info=True) %}
            {% set _ = run_query(stmt) %}
        {% endfor %}
        {% do log('grant_semantic_views_privileges: completed read grants', info=True) %}
    {% endfor %}
{% endmacro %}
