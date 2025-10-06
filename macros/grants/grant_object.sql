{% macro grant_object(object_type, objects, grant_types, grant_roles) %}
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
    {% set revokable_read_privs = ['SELECT','REFERENCES','REBUILD'] %}
    {% set revoke_statements = [] %}
    {% set grant_statements = [] %}

    {% for object in objects %}
        {% set existing_role_priv_map = {} %} {# key role -> list of privs #}
        {% do log('====> Processing ' ~ object_type ~ ' ' ~ object ~ ' with desired privileges ' ~ (grant_types | join(', ')) ~ ' for roles ' ~ (grant_roles | join(', ')), info=True) %}
        {% set query %}
            show grants on {{ object_type }} {{ target.database }}.{{ object }};
        {% endset %}
        {% set results = run_query(query) %}
        {% if results %}
            {% for row in results %}
                {% if row.privilege not in excluded_privs %}
                    {# classify existing privilege #}
                    {% set _role = row.grantee_name %}
                    {% set _priv = row.privilege %}
                    {% if _priv in grant_types %}
                        {% if _role not in grant_roles %}
                            {{ revoke_statements.append('revoke ' ~ _priv | lower ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' from role ' ~ _role | lower ~ ';') }}
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
                        {% if _role in grant_roles or _priv in revokable_read_privs %}
                            {{ revoke_statements.append('revoke ' ~ _priv | lower ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' from role ' ~ _role | lower ~ ';') }}
                        {% endif %}
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
                    {{ grant_statements.append('grant ' ~ privilege | lower ~ ' on ' ~ object_type ~ ' ' ~ target.database ~ '.' ~ object ~ ' to role ' ~ role | lower ~ ';') }}
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