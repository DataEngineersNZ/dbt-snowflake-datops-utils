{% macro get_functions(schema_list) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return([]) %}{% endif %}
    {% if not execute %}{% do return([]) %}{% endif %}
    {% set query %}
        select
            function_catalog,
            function_schema as schema_name,
            function_name,
            regexp_replace(
                listagg(trim(split_part(arg, ' ', -1)), ',') within group (order by 1),
                '^,',''
            ) as argument_signature
        from (
            select
                function_catalog,
                function_schema,
                function_name,
                function_number,
                trim(split_part(f.value, ' ', -1)) as arg
            from (
                select
                    function_catalog,
                    function_schema,
                    function_name,
                    split(replace(replace(argument_signature, '(', ''), ')', ''), ',') as args,
                    row_number() over (order by function_name) as function_number
                from information_schema.functions
                where function_schema in ({{ schema_list }})
            ), lateral flatten(input => args) as f
        )
        group by function_catalog, function_schema, function_name, function_number
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% do log('====> get_functions: query executed', info=True) %}
    {% if results and results | length > 0 %}
        {% for r in results %}
            {% do statements.append(target.database ~ '.' ~ r[1] ~ '.' ~ r[2] ~ '(' ~ r[3] ~ ')') %}
        {% endfor %}
        {% do log('get_functions: found ' ~ (statements | length) ~ ' functions', info=True) %}
    {% else %}
        {% do log('get_functions: no functions found', info=True) %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}