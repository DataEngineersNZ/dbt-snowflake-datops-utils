-- Macro: grant_agent_usage.sql
-- Description: Grants USAGE privilege on all AGENT views in a given schema to specified roles and revokes from other roles if they currently have it.
-- Usage: {{ grant_agent_usage(schema_name, grant_roles, revoke_roles) }}

{% macro grant_agent_usage(schema_name, grant_roles, revoke_roles) %}
  {% set views_query %}
    SELECT table_name
    FROM information_schema.views
    WHERE table_schema = '{{ schema_name }}'
      AND table_name LIKE '%AGENT%'
  {% endset %}

  {% set views = run_query(views_query) %}
  {% set statements = [] %}

  -- Grant USAGE on all AGENT views to specified roles
  {% for role in grant_roles %}
    {% for view in views %}
      {% set stmt %}GRANT USAGE ON VIEW {{ schema_name }}.{{ view['table_name'] }} TO ROLE {{ role }};{% endset %}
      {% do statements.append(stmt) %}
    {% endfor %}
  {% endfor %}

  -- Revoke USAGE only from roles that currently have it
  {% for view in views %}
    {% set grants_query %}
      SHOW GRANTS ON VIEW {{ schema_name }}.{{ view['table_name'] }}
    {% endset %}
    {% set grants = run_query(grants_query) %}
    {% for role in revoke_roles %}
      {% for grant in grants %}
        {% if grant['privilege'] == 'USAGE' and grant['grantee'] == role %}
          {% set stmt %}REVOKE USAGE ON VIEW {{ schema_name }}.{{ view['table_name'] }} FROM ROLE {{ role }};{% endset %}
          {% do statements.append(stmt) %}
        {% endif %}
      {% endfor %}
    {% endfor %}
  {% endfor %}

  -- Execute all statements
  {% for stmt in statements %}
    {{ stmt }}
  {% endfor %}
{% endmacro %}
