{% macro grant_share_read(view_names, grant_shares, revoke_current_grants) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do log('grant_share_read: skip (context)', info=True) %}{% do return(none) %}{% endif %}
    {% set dry_run = var('grants_dry_run', false) %}
    {% if view_names | length > 0 %}
        {% set schemas = [] %}
        {% for item in view_names %}
            {% set s = item.split('.')[0] %}
            {% if s not in schemas %}{% do schemas.append(s) %}{% endif %}
        {% endfor %}
        {% for schema in schemas %}
            {% set views = [] %}
            {% for item in view_names %}
                {% if item.split('.')[0] == schema %}{% do views.append(item.split('.')[1]) %}{% endif %}
            {% endfor %}
            {% do dbt_dataengineers_utils.grant_share_read_specific_schema(schema, views, grant_shares, revoke_current_grants, dry_run) %}
        {% endfor %}
    {% else %}
        {% if revoke_current_grants and execute %}
            {% set share_results = run_query('show shares;') %}
            {% set execute_statements = [] %}
            {% for share in share_results %}
                {% if share.kind == 'OUTBOUND' %}
                    {% set share_desc = run_query('desc share ' ~ share.name | lower  ~ ';') %}
                    {% for row in share_desc %}
                        {% if row[0] not in ['DATABASE'] and row[1].split('.')[0] | lower == target.database | lower %}
                            {% if row[0] == 'SCHEMA' %}
                                {% do execute_statements.append('revoke usage on ' ~ row[0] | lower ~ ' ' ~ row[1] | lower ~ ' from share ' ~ share.name ~ ';') %}
                            {% else %}
                                {% do execute_statements.append('revoke select on ' ~ row[0] | lower ~ ' ' ~ row[1] | lower ~ ' from share ' ~ share.name ~ ';') %}
                            {% endif %}
                        {% endif %}
                    {% endfor %}
                {% endif %}
            {% endfor %}
            {% for statement in execute_statements %}
                {% do log(statement, info=True) %}
                {% if not dry_run %}{% set _ = run_query(statement) %}{% endif %}
            {% endfor %}
            {% do log('grant_share_read: processed ' ~ (execute_statements | length) ~ ' revokes (dry_run=' ~ dry_run ~ ')', info=True) %}
        {% endif %}
    {% endif %}
{% endmacro %}

{% macro grant_share_read_specific_schema(schema_name, view_names, grant_shares, revoke_current_grants, dry_run) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return(none) %}{% endif %}
    {% set execute_statements = [] %}
    {% set snowflake_shares = [] %}
    {% if execute %}
        {% set share_results = run_query('show shares;') %}
        {% set current_account = run_query('select current_account();') %}
        {% for share in share_results %}
            {% if share.kind == 'OUTBOUND' and share.name not in snowflake_shares %}{% do snowflake_shares.append(share.name) %}{% endif %}
        {% endfor %}
        {% do log('grant_share_read_specific_schema: processing schema ' ~ schema_name | lower, info=True) %}
        {% if revoke_current_grants %}
            {% set results = run_query('show grants on schema ' ~ target.database | lower ~ '.' ~ schema_name | lower ~ ';') %}
            {% for row in results %}
                {% if row.privilege == 'USAGE' and row.granted_to == 'SHARE' %}
                    {% if row.grantee_name.replace(current_account[0][0] ~ '.', '') not in grant_shares and row.grantee_name in snowflake_shares %}
                        {% do execute_statements.append('revoke usage on schema ' ~ target.database ~ '.' ~ schema_name | lower ~ ' from share ' ~ row.grantee_name | lower ~ ';') %}
                    {% endif %}
                {% endif %}
            {% endfor %}
            {% for share in snowflake_shares %}
                {% do log('Inspecting share ' ~ share | lower, info=True) %}
                {% set share_desc = run_query('desc share ' ~ share | lower  ~ ';') %}
                {% for row in share_desc %}
                    {% if row[0] not in ['DATABASE','SCHEMA'] and row[1].split('.')[0] | lower == target.database | lower and row[1].split('.')[1] | lower == schema_name | lower %}
                        {% set view_name = row[1].split('.')[2] | lower %}
                        {% if share not in grant_shares or view_name not in (view_names | map('lower') | list) %}
                            {% do execute_statements.append('revoke select on ' ~ row[0] ~ ' ' ~ row[1] ~ ' from share ' ~ share ~ ';') %}
                        {% endif %}
                    {% endif %}
                {% endfor %}
            {% endfor %}
        {% endif %}
        {% for share in grant_shares %}
            {% do execute_statements.append('grant usage on schema ' ~ target.database ~ '.' ~ schema_name ~ ' to share ' ~ share ~ ';') %}
            {% for view in view_names %}
                {% do execute_statements.append('grant select on view ' ~ target.database ~ '.' ~ schema_name ~ '.' ~ view ~ ' to share ' ~ share ~ ';') %}
            {% endfor %}
        {% endfor %}
        {% for statement in execute_statements %}
            {% do log(statement, info=True) %}
            {% if not dry_run %}{% set _ = run_query(statement) %}{% endif %}
        {% endfor %}
        {% do log('grant_share_read_specific_schema summary: executed ' ~ (execute_statements | length) ~ ' statements (dry_run=' ~ dry_run ~ ')', info=True) %}
    {% endif %}
{% endmacro %}