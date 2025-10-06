{% macro grant_schema_procedure_usage(exclude_schemas, grant_roles) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do log('grant_schema_procedure_usage: skip (context)', info=True) %}{% do return(none) %}{% endif %}
    {% set dry_run = var('grants_dry_run', false) %}
    {% if 'INFORMATION_SCHEMA' not in exclude_schemas %}{% do exclude_schemas.append('INFORMATION_SCHEMA') %}{% endif %}
    {% set include_schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas) %}
    {% if include_schemas | length == 0 %}{% do log('grant_schema_procedure_usage: no schemas to process', info=True) %}{% do return(none) %}{% endif %}
    {% do log('grant_schema_procedure_usage: processing ' ~ (include_schemas | length) ~ ' schemas for roles: ' ~ (grant_roles | join(', ')), info=True) %}
    {% do dbt_dataengineers_utils.grant_schema_procedure_usage_specific(include_schemas, grant_roles, true, dry_run) %}
{% endmacro %}

{% macro grant_schema_procedure_usage_specific(schemas, grant_roles, revoke_current_grants, dry_run) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return(none) %}{% endif %}
    {% if schemas | length == 0 or grant_roles | length == 0 %}{% do log('grant_schema_procedure_usage_specific: nothing to do', info=True) %}{% do return(none) %}{% endif %}
    {% set total_revokes = 0 %}
    {% set total_grants = 0 %}
    {% for schema in schemas %}
        {% set existing_roles = [] %}

        {# Get list of procedures in the schema using the pattern provided #}
        {% set proc_query %}
            show procedures in schema {{ target.database }}.{{ schema }}
            ->>
            select
                "name" as object_name,
                "schema_name" as routine_schema,
                SUBSTR(
                    "arguments",
                    POSITION('(' IN "arguments") + 1,
                    POSITION(')' IN "arguments") - POSITION('(' IN "arguments") - 1
                ) AS arguments,
                concat("name", '(',
                    SUBSTR(
                        "arguments",
                        POSITION('(' IN "arguments") + 1,
                        POSITION(')' IN "arguments") - POSITION('(' IN "arguments") - 1
                    ),
                ')') as routine_name
            from $1
            where "is_builtin" = 'N'
        {% endset %}

        {# First run show procedures to populate result_scan #}
        {% set show_proc_stmt = 'show procedures in schema ' ~ target.database ~ '.' ~ schema %}
        {% set _ = run_query(show_proc_stmt) %}

        {# Now get the formatted procedure list #}
        {% set proc_results = run_query(proc_query) %}
        {% set procedures = [] %}

        {% if execute and proc_results %}
            {% for row in proc_results %}
                {% set full_proc_name = row[3] %}
                {% do procedures.append(full_proc_name) %}
            {% endfor %}
        {% endif %}

        {% if procedures | length == 0 %}
            {% do log('grant_schema_procedure_usage_specific: no procedures found in schema ' ~ schema, info=True) %}
        {% else %}
            {% do log('grant_schema_procedure_usage_specific: found ' ~ (procedures | length) ~ ' procedures in schema ' ~ schema, info=True) %}

            {# Check existing grants for each procedure #}
            {% for procedure in procedures %}
                {% set grant_query %}
                    show grants on procedure {{ target.database }}.{{ schema }}.{{ procedure }}
                {% endset %}
                {% set grant_results = run_query(grant_query) %}

                {% if execute and grant_results %}
                    {% for row in grant_results %}
                        {% set priv = row.privilege %}{% set grantee = row.grantee_name %}
                        {% if priv == 'USAGE' %}
                            {% if grantee not in grant_roles %}
                                {% if revoke_current_grants %}
                                    {% set stmt = 'revoke usage on procedure ' ~ target.database ~ '.' ~ schema ~ '.' ~ procedure ~ ' from role ' ~ grantee ~ ';' %}
                                    {% do log(stmt, info=True) %}
                                    {% if not dry_run %}{% set _ = run_query(stmt) %}{% endif %}
                                    {% set total_revokes = total_revokes + 1 %}
                                {% endif %}
                            {% else %}
                                {% if grantee not in existing_roles %}
                                    {% do existing_roles.append(grantee) %}
                                {% endif %}
                            {% endif %}
                        {% endif %}
                    {% endfor %}
                {% endif %}
            {% endfor %}

            {# Grant schema usage first #}
            {% for role in grant_roles %}
                {% set schema_stmt = 'grant usage on schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';' %}
                {% do log(schema_stmt, info=True) %}
                {% if not dry_run %}{% set _ = run_query(schema_stmt) %}{% endif %}
                {% set total_grants = total_grants + 1 %}
            {% endfor %}

            {# Grant procedure usage #}
            {% for role in grant_roles %}
                {% set needs_grant = true %}
                {# Check if role already has USAGE on any procedure in this schema #}
                {% for procedure in procedures %}
                    {% set grant_query %}
                        show grants on procedure {{ target.database }}.{{ schema }}.{{ procedure }}
                    {% endset %}
                    {% set grant_results = run_query(grant_query) %}
                    {% if execute and grant_results %}
                        {% for row in grant_results %}
                            {% if row.privilege == 'USAGE' and row.grantee_name == role %}
                                {% set needs_grant = false %}
                                {% break %}
                            {% endif %}
                        {% endfor %}
                    {% endif %}
                    {% if not needs_grant %}{% break %}{% endif %}
                {% endfor %}

                {% if needs_grant %}
                    {% set stmt = 'grant usage on all procedures in schema ' ~ target.database ~ '.' ~ schema ~ ' to role ' ~ role ~ ';' %}
                    {% do log(stmt, info=True) %}
                    {% if not dry_run %}{% set _ = run_query(stmt) %}{% endif %}
                    {% set total_grants = total_grants + 1 %}
                {% endif %}
            {% endfor %}
        {% endif %}
    {% endfor %}
    {% do log('grant_schema_procedure_usage_specific summary: ' ~ total_revokes ~ ' revokes, ' ~ total_grants ~ ' grants (dry_run=' ~ dry_run ~ ')', info=True) %}
{% endmacro %}
