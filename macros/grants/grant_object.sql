{% macro grant_object(object_type, objects, grant_types, grant_roles) %}
    {# Grant-only: no revokes are performed. Signature unchanged. #}
    {% if flags.WHICH not in ['run', 'run-operation'] %}
        {% do log('Skipping grant_object: not run/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping grant_object: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if objects | length == 0 %}
        {% do log('grant_object: no objects supplied for ' ~ object_type, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set grant_roles = dbt_dataengineers_utils._grants_normalize_roles(grant_roles) %}
    {% set grant_statements = [] %}

    {% for object in objects %}
        {% set existing_role_priv_map = {} %}
        {% do log('====> Processing ' ~ object_type ~ ' ' ~ object ~ ' with desired privileges ' ~ (grant_types | join(', ')) ~ ' for roles ' ~ (grant_roles | join(', ')), info=True) %}
        {% set query %}
            show grants on {{ object_type }} {{ target.database }}.{{ object }};
        {% endset %}
        {% set results = run_query(query) %}
        {% if results %}
            {% for row in results %}
                {% set _role = row.grantee_name | upper %}
                {% set _priv = row.privilege %}
                {% if _priv in grant_types and _role in grant_roles %}
                    {% if existing_role_priv_map.get(_role) is none %}
                        {% set _ = existing_role_priv_map.update({_role: []}) %}
                    {% endif %}
                    {% if _priv not in existing_role_priv_map.get(_role) %}
                        {% set __ = existing_role_priv_map.get(_role).append(_priv) %}
                    {% endif %}
                {% endif %}
            {% endfor %}
        {% endif %}

        {# Determine grants needed #}
        {% for role in grant_roles %}
            {% set existing_for_role = existing_role_priv_map.get(role) if existing_role_priv_map.get(role) is not none else [] %}
            {% do log('====> Existing grants for role ' ~ role ~ ' on ' ~ object ~ ' : ' ~ (existing_for_role | join(', ')), info=True) %}
            {% for privilege in grant_types %}
                {% if privilege not in existing_for_role %}
                    {% do grant_statements.append('grant ' ~ privilege | lower ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' to role ' ~ role | lower ~ ';') %}
                {% endif %}
            {% endfor %}
        {% endfor %}
    {% endfor %}

    {% if grant_statements | length == 0 %}
        {% do log('grant_object: no changes required for supplied ' ~ object_type ~ ' objects', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('grant_object summary: ' ~ grant_statements | length ~ ' grants for ' ~ object_type ~ ' objects', info=True) %}
    {% for stmt in grant_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}
    {% do log('grant_object: completed granting privileges for ' ~ object_type ~ ' objects', info=True) %}
{% endmacro %}