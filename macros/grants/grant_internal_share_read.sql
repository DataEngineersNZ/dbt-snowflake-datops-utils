{% macro grant_internal_share_read(share_name, exclude_schemas=[]) %}
  {% set database = target.database %}
  {% set schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas) %}
  {% do log("Granting SELECT on all tables and views in all schemas for share: " ~ share_name, info=True) %}
  {% for schema in schemas %}
    {# Get all tables in the schema #}
    {% set schema_query %}
      grant usage on schema {{ database }}.{{ schema }} to share {{ share_name }};
    {% endset %}
    {% do run_query(schema_query) %}
    {% set tables_query %}
      show tables in schema {{ database }}.{{ schema }};
    {% endset %}
    {% set tables_result = run_query(tables_query) %}
    {% if execute and tables_result is not none %}
      {% for row in tables_result %}
        {% set grant_table_sql %}
          grant select on table {{ database }}.{{ schema }}.{{ row.name }} to share {{ share_name }};
        {% endset %}
        {% do run_query(grant_table_sql) %}
      {% endfor %}
    {% endif %}
    {# Get all views in the schema #}
    {% set views_query %}
      show views in schema {{ database }}.{{ schema }};
    {% endset %}
    {% set views_result = run_query(views_query) %}
    {% if execute and views_result is not none %}
      {% for row in views_result %}
        {% set grant_view_sql %}
          grant select on view {{ database }}.{{ schema }}.{{ row.name }} to share {{ share_name }};
        {% endset %}
        {% do run_query(grant_view_sql) %}
      {% endfor %}
    {% endif %}
  {% endfor %}
{% endmacro %}
