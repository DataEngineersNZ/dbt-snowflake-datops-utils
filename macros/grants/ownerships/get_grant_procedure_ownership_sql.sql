{% macro get_grant_procedure_ownership_sql(schema_list, role_name) %}
    {% set query %}
        select
            procedure_catalog,
            procedure_schema as schema_name,
            procedure_name,
            listagg(trim(split_part(arg, ' ', -1)), ',') within group (order by arg) as argument_signature
        from (
            select
                procedure_catalog,
                procedure_schema,
                procedure_name,
                trim(split_part(f.value, ' ', -1)) as arg
            from (
                select
                    procedure_catalog,
                    procedure_schema,
                    procedure_name,
                    split(replace(replace(argument_signature, '(', ''), ')', ''), ',') as args
                from information_schema.procedures
                where procedure_owner = '{{ role_name | upper }}'
                and procedure_schema in ({{ schema_list }})
            ),
            lateral flatten(input => args) as f
            where trim(f.value) <> ''
        )
        group by procedure_catalog, procedure_schema, procedure_name;
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results | length > 0 %}
        {% for result in results %}
            {{ statements.append(" grant ownership on procedure " ~ target.database ~ "." ~ result.schema_name ~ "." ~ result.procedure_name ~ "(" ~ result.argument_signature ~ ") to role " ~ role_name ~ " revoke current grants;") }}
        {% endfor %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}