{% macro get_grant_other_ownership_sql(schema_list, role_name) %}
    {% set query %}
        with object_data as (
            select 'sequence' as object_type, sequence_catalog as database_name, sequence_schema as schema_name, sequence_name as object_name, sequence_owner as object_owner
            from information_schema.sequences
            union all
            select 'stage' as object_type, stage_catalog, stage_schema, stage_name, stage_owner
            from information_schema.stages
            union all
            select 'file format' as object_type, file_format_catalog, file_format_schema, file_format_name, file_format_owner
            from information_schema.file_formats
        )
        select object_type, database_name, schema_name, object_name
        from object_data
        where object_owner != '{{ role_name | upper }}'
        and schema_name in ({{ schema_list }});
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results | length > 0 %}
        {% for result in results %}
            {{ statements.append(" grant ownership on network rule " ~ target.database ~ "." ~ result.schema_name ~ "." ~ result.object_name ~ " to role " ~ role_name ~ " revoke current grants;") }}
        {% endfor %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}

