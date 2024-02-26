{% macro database_clone(source_database, destination_database, new_owner_role='', comment='') %}

  {% if source_database and destination_database %}

    {{ (log("Cloning existing database " ~ source_database ~ " into database " ~ destination_database, info=True)) }}

    {% call statement('clone_database', fetch_result=True, auto_begin=False) -%}
        create or replace database {{ destination_database }} clone {{ source_database }} comment = '{{ comment }}';
    {%- endcall %}

    {%- set result = load_result('clone_database') -%}
    {{ log(result['data'][0][0], info=True)}}

  {% else %}

    {{ exceptions.raise_compiler_error("Invalid arguments. Missing source database and/or destination database") }}

  {% endif %}

  {% if new_owner_role != '' %}

    {{ log("Grant ownership on " ~ destination_database ~ " to " ~ new_owner_role, info=True)}}

    {% call statement('clone_database', fetch_result=True, auto_begin=False) -%}
        grant ownership on database {{ destination_database }} to role{{ new_owner_role }};
    {%- endcall %}

    {% set list_schemas_query %}
    -- get all schemata within the cloned database to then iterate through them and
    -- change their ownership
    select schema_name
    from {{ destination_database }}.information_schema.schemata
    where schema_name != 'INFORMATION_SCHEMA'
    {% endset %}

    {% set results = run_query(list_schemas_query) %}

    {% if execute %}
        {# Return the first column #}
        {% set schemata_list = results.columns[0].values() %}
    {% else %}
        {% set schemata_list = [] %}
    {% endif %}

    {% set queries = [] %}
    {% for schema_name in schemata_list %}
        {{ queries.append(" grant ownership on schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all materialized views in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all external tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all dynamic tables in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all stages in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all file formats in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all functions in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all sequences in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all procedures in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all streams in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all tasks in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
        {{ queries.append(" grant ownership on all masking policies in schema " ~ target.database ~ "." ~ schema ~ " to role " ~ role_name ~ "revoke current grants;") }}
    {% endfor %}
    {% for query in queries %}
        {% do log(query, info=True) %}
        {% set grant = run_query(query) %}
    {% endfor %}
  {% endif %}
{% endmacro %}
