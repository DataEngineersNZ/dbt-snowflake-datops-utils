{% macro get_procedures(schema_list) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return([]) %}{% endif %}
    {% if not execute %}{% do return([]) %}{% endif %}
    {% set query %}
        select
            procedure_catalog,
            procedure_schema as schema_name,
            procedure_name,
            regexp_replace(
                listagg(trim(split_part(arg, ' ', -1)), ',') within group (order by arg),
                '^,',''
            ) as argument_signature
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
                where procedure_schema in ({{ schema_list }})
            ), lateral flatten(input => args) as f
        )
        group by procedure_catalog, procedure_schema, procedure_name
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results and results | length > 0 %}
        {% for r in results %}
            {% do statements.append(target.database ~ '.' ~ r[1] ~ '.' ~ r[2] ~ '(' ~ r[3] ~ ')') %}
        {% endfor %}
        {% do log('get_procedures: found ' ~ (statements | length) ~ ' procedures', info=True) %}
    {% else %}
        {% do log('get_procedures: no procedures found', info=True) %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}