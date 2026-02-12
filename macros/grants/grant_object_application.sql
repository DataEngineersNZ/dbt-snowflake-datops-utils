{% macro grant_object_application(object_type, objects, grant_types, grant_applications) %}
    {# Optimized: logs summary instead of returning a structure. Signature unchanged. #}
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

    {% set excluded_privs = ['OWNERSHIP'] %} {# Always ignore these for grant/revoke logic #}
    {% set revokable_read_privs = ['SELECT'] %}
    {% set revoke_statements = [] %}
    {% set grant_statements = [] %}

    {% for object in objects %}
        {% set existing_role_priv_map = {} %} {# key role -> list of privs #}
        {% do log('====> Processing ' ~ object_type ~ ' ' ~ object ~ ' with desired privileges ' ~ (grant_types | join(', ')) ~ ' for applications ' ~ (grant_applications | join(', ')), info=True) %}
        {% set query %}
            show grants on {{ object_type }} {{ target.database }}.{{ object }};
        {% endset %}
        {% set results = run_query(query) %}
        {% if results %}
            {% for row in results %}
                {% if row.granted_to == 'APPLICATION' and row.privilege not in excluded_privs %}
                    {# classify existing privilege #}
                    {% set _role = row.grantee_name %}
                    {% set _priv = row.privilege %}
                    {% if _priv in grant_types %}
                        {% if _role not in grant_applications %}
                            {{ revoke_statements.append('revoke ' ~ _priv | lower ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' from application ' ~ _role | lower ~ ';') }}
                        {% else %}
                            {# track existing desired priv #}
                            {% if existing_role_priv_map.get(_role) is none %}
                                {% set _ = existing_role_priv_map.update({_role: []}) %}
                            {% endif %}
                            {% if _priv not in existing_role_priv_map.get(_role) %}
                                {% set __ = existing_role_priv_map.get(_role).append(_priv) %}
                            {% endif %}
                        {% endif %}
                    {% else %}
                        {# privilege not desired -> revoke if granted to managed roles #}
                        {% if _role in grant_applications or _priv in revokable_read_privs %}
                            {{ revoke_statements.append('revoke ' ~ _priv | lower ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' from application ' ~ _role | lower ~ ';') }}
                        {% endif %}
                    {% endif %}
                {% endif %}
            {% endfor %}
        {% endif %}

        {# Determine grants needed #}
        {% for application in grant_applications %}
            {% set existing_for_application = existing_role_priv_map.get(application) if existing_role_priv_map.get(application) is not none else [] %}
            {% do log('====> Existing grants for application ' ~ application ~ ' on ' ~ object ~ ' : ' ~ (existing_for_application | join(', ')), info=True) %}
            {% for privilege in grant_types %}
                {% if privilege not in existing_for_application %}
                    {{ grant_statements.append('grant ' ~ privilege | lower ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' to application ' ~ application | lower ~ ';') }}
                {% endif %}
            {% endfor %}
        {% endfor %}
    {% endfor %}

    {% set total_revokes = revoke_statements | length %}
    {% set total_grants = grant_statements | length %}
    {% set all_statements = revoke_statements + grant_statements %}
    {% if all_statements | length == 0 %}
        {% do log('grant_object: no changes required for supplied ' ~ object_type ~ ' objects', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('grant_object summary: ' ~ total_revokes ~ ' revokes, ' ~ total_grants ~ ' grants (' ~ all_statements | length ~ ' total statements) for ' ~ object_type ~ ' objects', info=True) %}
    {% for stmt in all_statements %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}
    {% do log('grant_object: completed privilege reconciliation for ' ~ object_type ~ ' objects', info=True) %}
{% endmacro %}