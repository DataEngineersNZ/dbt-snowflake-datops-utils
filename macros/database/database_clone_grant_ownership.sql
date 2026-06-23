{% macro database_clone_grant_ownership(destination_database, new_owner_role) %}

  {% if not destination_database or not new_owner_role %}
    {{ exceptions.raise_compiler_error("Invalid arguments. Missing destination_database and/or new_owner_role") }}
  {% endif %}

  {{ log("Granting ownership on " ~ destination_database ~ " to " ~ new_owner_role, info=True) }}

  {% call statement('grant_db_ownership', fetch_result=True, auto_begin=False) -%}
      GRANT OWNERSHIP ON DATABASE {{ destination_database }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
  {%- endcall %}

  {% set list_schemas_query %}
    SELECT schema_name
    FROM {{ destination_database }}.information_schema.schemata
    WHERE schema_name != 'INFORMATION_SCHEMA'
  {% endset %}

  {% if execute %}
    {% set results = run_query(list_schemas_query) %}
    {% set schemata_list = results.columns[0].values() %}
  {% else %}
    {% set schemata_list = [] %}
  {% endif %}

  {% for schema_name in schemata_list %}
    {{ log("Granting ownership on schema " ~ destination_database ~ "." ~ schema_name ~ " to " ~ new_owner_role, info=True) }}

    {% call statement('grant_schema_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_views_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL VIEWS IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_mat_views_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL MATERIALIZED VIEWS IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_tables_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL TABLES IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_ext_tables_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL EXTERNAL TABLES IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_dyn_tables_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL DYNAMIC TABLES IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_stages_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL STAGES IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_file_formats_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL FILE FORMATS IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_functions_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL FUNCTIONS IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_procedures_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL PROCEDURES IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_streams_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL STREAMS IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

    {% call statement('grant_tasks_' ~ loop.index, auto_begin=False) -%}
        GRANT OWNERSHIP ON ALL TASKS IN SCHEMA {{ destination_database }}.{{ schema_name }} TO ROLE {{ new_owner_role }} REVOKE CURRENT GRANTS;
    {%- endcall %}

  {% endfor %}

{% endmacro %}
