{% macro get_grant_other_ownership_sql(schema_list, role_name) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return([]) %}{% endif %}
    {% if not execute %}{% do return([]) %}{% endif %}
    {% set query %}
        with object_data as (
            select 'sequence' as object_type, sequence_catalog as database_name, sequence_schema as schema_name, sequence_name as object_name, sequence_owner as object_owner from information_schema.sequences
            union all
            select 'stage' as object_type, stage_catalog, stage_schema, stage_name, stage_owner from information_schema.stages
            union all
            select 'file format' as object_type, file_format_catalog, file_format_schema, file_format_name, file_format_owner from information_schema.file_formats
        )
        select object_type, database_name, schema_name, object_name
        from object_data
        where object_owner != '{{ role_name | upper }}'
          and schema_name in ({{ schema_list }})
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results and results | length > 0 %}
        {% for r in results %}
            {% if not r[3].startswith('temp_file_format') %}
                {% do statements.append('grant ownership on ' ~ r[0] ~ ' ' ~ target.database ~ '.' ~ r[2] ~ '.' ~ r[3] ~ ' to role ' ~ role_name ~ ' revoke current grants;') %}
            {% endif %}
        {% endfor %}
        {% do log('get_grant_other_ownership_sql: generated ' ~ (statements | length) ~ ' statements', info=True) %}
    {% else %}
        {% do log('get_grant_other_ownership_sql: no ownership changes required for other object types', info=True) %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}

