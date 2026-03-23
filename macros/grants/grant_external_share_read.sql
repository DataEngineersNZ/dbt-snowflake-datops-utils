{% macro grant_internal_share_read(share_name, include_schemas, dry_run=false) %}
  {% if flags.WHICH in ['run', 'run-operation'] %}
    {% if execute %}
      {% set database = target.database %}
      {% if include_schemas is none %}
        {% set include_schemas = [] %}
      {% elif include_schemas is string %}
        {% set include_schemas = [include_schemas] %}
      {% elif include_schemas is not iterable %}
        {% set include_schemas = [] %}
      {% endif %}
      {% if include_schemas | length == 0 %}
        {% do log("No schemas to grant for share: " ~ share_name, info=True) %}
        {% do return(none) %}
      {% endif %}
      {% set schemas = dbt_dataengineers_utils._grants_collect_schemas(include_schemas, is_exclude_list=false) %}
      {% do log("Granting SELECT on all tables and views in all schemas for share: " ~ share_name ~ " (dry_run=" ~ dry_run ~ ")", info=True) %}
      {% for schema in schemas %}
        {% set grant_usage %}
          grant usage on schema {{ database }}.{{ schema }} to share {{ share_name }};
        {% endset %}
        {% if dry_run %}
          {% do log(grant_usage, info=True) %}
        {% else %}
          {% do run_query(grant_usage) %}
        {% endif %}
        {# Grant SELECT on all tables in schema #}
        {% set grant_tables_sql %}
          grant select on all tables in schema {{ database }}.{{ schema }} to share {{ share_name }};
        {% endset %}
        {% if dry_run %}
          {% do log(grant_tables_sql, info=True) %}
        {% else %}
          {% do run_query(grant_tables_sql) %}
        {% endif %}

        {# Grant SELECT on views individually #}
        {% set views_query %}
          show views in schema {{ database }}.{{ schema }};
        {% endset %}
        {% set views_result = run_query(views_query) %}
        {% if execute and views_result is not none %}
          {% for row in views_result %}
            {% set grant_view_sql %}
              grant select on view {{ database }}.{{ schema }}.{{ row.name }} to share {{ share_name }};
            {% endset %}
            {% if dry_run %}
              {% do log(grant_view_sql, info=True) %}
            {% else %}
              {% do run_query(grant_view_sql) %}
            {% endif %}
          {% endfor %}
        {% endif %}
      {% endfor %}
    {% endif %}
  {% endif %}
{% endmacro %}
