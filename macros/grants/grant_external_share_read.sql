{% macro grant_external_share_read(share_name, include_schemas, dry_run=false) %}
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

      {# Get existing share grants once upfront #}
      {% set existing_share_objects = [] %}
      {% set share_desc = run_query('desc share ' ~ share_name ~ ';') %}
      {% if share_desc %}
        {% for row in share_desc %}
          {% do existing_share_objects.append(row[0] ~ ':' ~ row[1] | upper) %}
        {% endfor %}
      {% endif %}

      {% set total_executed = 0 %}
      {% set schemas_skipped = 0 %}
      {% do log("Granting SELECT on all tables and views in specified schemas for share: " ~ share_name ~ " (dry_run=" ~ dry_run ~ ")", info=True) %}
      {% for schema in schemas %}
        {% set schema_statements = [] %}

        {# Check if schema USAGE already granted #}
        {% if 'SCHEMA:' ~ database | upper ~ '.' ~ schema | upper not in existing_share_objects %}
          {% do schema_statements.append('grant usage on schema ' ~ database ~ '.' ~ schema ~ ' to share ' ~ share_name ~ ';') %}
        {% endif %}

        {# Check if tables grant exists #}
        {% set has_table_grants = [] %}
        {% for obj in existing_share_objects %}
          {% if obj.startswith('TABLE:' ~ database | upper ~ '.' ~ schema | upper ~ '.') %}
            {% do has_table_grants.append(1) %}
          {% endif %}
        {% endfor %}
        {% if has_table_grants | length == 0 %}
          {% do schema_statements.append('grant select on all tables in schema ' ~ database ~ '.' ~ schema ~ ' to share ' ~ share_name ~ ';') %}
        {% endif %}

        {# Grant SELECT on views individually (shares require individual view grants) #}
        {% set views_query %}
          show views in schema {{ database }}.{{ schema }};
        {% endset %}
        {% set views_result = run_query(views_query) %}
        {% if execute and views_result is not none %}
          {% for row in views_result %}
            {% set view_key = 'VIEW:' ~ database | upper ~ '.' ~ schema | upper ~ '.' ~ row.name | upper %}
            {% if view_key not in existing_share_objects %}
              {% do schema_statements.append('grant select on view ' ~ database ~ '.' ~ schema ~ '.' ~ row.name ~ ' to share ' ~ share_name ~ ';') %}
            {% endif %}
          {% endfor %}
        {% endif %}

        {% if schema_statements | length == 0 %}
          {% set schemas_skipped = schemas_skipped + 1 %}
        {% else %}
          {% for stmt in schema_statements %}
            {% if dry_run %}
              {% do log(stmt, info=True) %}
            {% else %}
              {% do run_query(stmt) %}
            {% endif %}
          {% endfor %}
          {% set total_executed = total_executed + schema_statements | length %}
        {% endif %}
      {% endfor %}
      {% do log('grant_external_share_read: ' ~ total_executed ~ ' statements executed, ' ~ schemas_skipped ~ '/' ~ (schemas | length) ~ ' schemas skipped (dry_run=' ~ dry_run ~ ')', info=True) %}
    {% endif %}
  {% endif %}
{% endmacro %}
