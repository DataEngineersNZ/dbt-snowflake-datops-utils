{#
-- This macro clones the source schema into the destination schema and
-- optionally grants ownership over it and its tables and views to a new owner.
#}
{% macro schema_clone(source_schema, destination_schema, source_database=target.database, destination_database=target.database, new_owner_role='') %}
    {% if source_schema and destination_schema %}
        {{ (log("Cloning existing schema " ~ source_database ~ "." ~ source_schema ~ " into schema " ~ destination_database ~ "." ~ destination_schema, info=True)) }}
        {% call statement('clone_schema', fetch_result=True, auto_begin=False) -%}
            create or replace schema {{ destination_database }}.{{ destination_schema }} clone {{ source_database }}.{{ source_schema }}
        {%- endcall %}
        {%- set result = load_result('clone_schema') -%}
        {{ log(result['data'][0][0], info=True)}}
    {% else %}
        {{ exceptions.raise_compiler_error("Invalid arguments. Missing source schema and/or destination schema") }}
    {% endif %}

    {% if new_owner_role != '' %}
        grant ownership on schema {{ destination_database }}.{{ destination_schema }} to role {{ role_name }} revoke current grants;
        grant ownership on all views in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all materialized views in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all tables in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all external tables in {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all dynamic tables in {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all stages in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all file formats in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all functions in schema {{ destination_database }}.{{ destination_schema }} to role {{ role_name }} revoke current grants;
        grant ownership on all sequences in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all procedures in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all streams in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all tasks in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;
        grant ownership on all masking policies in schema {{ destination_database }}.{{ destination_schema }} to role {{ new_owner_role }} revoke current grants;

  {% endif %}

{% endmacro %}