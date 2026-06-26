{% macro grant_internal_share_read(share_name, exclude_schemas=none, dry_run=false) %}
  {% if flags.WHICH in ['run', 'run-operation'] %}
    {% if execute %}
      {% set database = target.database %}
      {% if exclude_schemas is none %}
        {% set exclude_schemas = [] %}
      {% elif exclude_schemas is string %}
        {% set exclude_schemas = [exclude_schemas] %}
      {% elif exclude_schemas is not iterable %}
        {% set exclude_schemas = [] %}
      {% endif %}
      {% set schemas = dbt_dataengineers_utils._grants_collect_schemas(exclude_schemas, is_exclude_list=true) %}

      {# Get existing share grants once upfront #}
      {% set existing_share_objects = {} %}
      {% set schemas_with_table_grants = [] %}
      {% set share_desc = run_query('desc share ' ~ share_name ~ ';') %}
      {% if share_desc %}
        {% for row in share_desc %}
          {% set key = row[0] ~ ':' ~ row[1] | upper %}
          {% set _ = existing_share_objects.update({key: true}) %}
          {# Track which schemas already have table grants #}
          {% if row[0] == 'TABLE' %}
            {% set parts = row[1].split('.') %}
            {% if parts | length >= 2 %}
              {% set schema_key = parts[0] | upper ~ '.' ~ parts[1] | upper %}
              {% if schema_key not in schemas_with_table_grants %}
                {% do schemas_with_table_grants.append(schema_key) %}
              {% endif %}
            {% endif %}
          {% endif %}
        {% endfor %}
      {% endif %}

      {# Bulk fetch all views across the database in one query #}
      {% set all_views = {} %}
      {% set views_bulk_query %}
        select table_schema, table_name
        from information_schema.tables
        where table_type = 'VIEW'
          and table_schema != 'INFORMATION_SCHEMA'
      {% endset %}
      {% set views_bulk_result = run_query(views_bulk_query) %}
      {% if execute and views_bulk_result %}
        {% for row in views_bulk_result %}
          {% set s = row[0] %}
          {% if all_views.get(s) is none %}
            {% set _ = all_views.update({s: []}) %}
          {% endif %}
          {% do all_views.get(s).append(row[1]) %}
        {% endfor %}
      {% endif %}

      {% set total_executed = 0 %}
      {% set schemas_skipped = 0 %}
      {% do log("Granting SELECT on all tables and views in all schemas for share: " ~ share_name ~ " (dry_run=" ~ dry_run ~ ")", info=True) %}
      {% for schema in schemas %}
        {% set schema_statements = [] %}

        {# Check if schema USAGE already granted #}
        {% set schema_key = 'SCHEMA:' ~ database | upper ~ '.' ~ schema | upper %}
        {% if existing_share_objects.get(schema_key) is none %}
          {% do schema_statements.append('grant usage on schema ' ~ database ~ '.' ~ schema ~ ' to share ' ~ share_name ~ ';') %}
        {% endif %}

        {# Check if tables already granted (O(1) lookup using pre-built set) #}
        {% set db_schema_key = database | upper ~ '.' ~ schema | upper %}
        {% if db_schema_key not in schemas_with_table_grants %}
          {% do schema_statements.append('grant select on all tables in schema ' ~ database ~ '.' ~ schema ~ ' to share ' ~ share_name ~ ';') %}
        {% endif %}

        {# Grant SELECT on views individually (shares require individual view grants) #}
        {% set schema_views = all_views.get(schema, []) %}
        {% for view_name in schema_views %}
          {% set view_key = 'VIEW:' ~ database | upper ~ '.' ~ schema | upper ~ '.' ~ view_name | upper %}
          {% if existing_share_objects.get(view_key) is none %}
            {% do schema_statements.append('grant select on view ' ~ database ~ '.' ~ schema ~ '.' ~ view_name ~ ' to share ' ~ share_name ~ ';') %}
          {% endif %}
        {% endfor %}

        {% if schema_statements | length == 0 %}
          {% set schemas_skipped = schemas_skipped + 1 %}
        {% else %}
          {% for stmt in schema_statements %}
            {% if dry_run %}
              {% do log(stmt, info=True) %}
            {% else %}
              {% do log(stmt, info=True) %}
              {% do run_query(stmt) %}
            {% endif %}
          {% endfor %}
          {% set total_executed = total_executed + schema_statements | length %}
        {% endif %}
      {% endfor %}
      {% do log('grant_internal_share_read: ' ~ total_executed ~ ' statements executed, ' ~ schemas_skipped ~ '/' ~ (schemas | length) ~ ' schemas skipped (dry_run=' ~ dry_run ~ ')', info=True) %}
    {% endif %}
  {% endif %}
{% endmacro %}
