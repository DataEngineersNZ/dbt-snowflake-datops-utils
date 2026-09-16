{% macro create_database_role(database_role_names, comment=none) %}
    {# Creates one or more database roles in the target database. Idempotent via IF NOT EXISTS
       (avoids CREATE OR REPLACE, which Snowflake docs warn drops the role from any shares it's granted to). #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping create_database_role: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping create_database_role: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if database_role_names is string %}
        {% set role_names = [database_role_names] %}
    {% else %}
        {% set role_names = database_role_names %}
    {% endif %}

    {% if role_names | length == 0 %}
        {% do log('create_database_role: no database role names supplied', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% for role_name in role_names %}
        {% set stmt %}
            create database role if not exists {{ target.database }}.{{ role_name | lower }}
            {%- if comment %} comment = '{{ comment }}'{% endif -%};
        {% endset %}
        {% do log(stmt, info=True) %}
        {% set _ = run_query(stmt) %}
    {% endfor %}

    {% do log('create_database_role: completed creating ' ~ (role_names | length) ~ ' database role(s) in ' ~ target.database, info=True) %}
{% endmacro %}
