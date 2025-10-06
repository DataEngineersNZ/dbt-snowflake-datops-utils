{% macro get_grant_functions_ownership_sql(schema_list, role_name) %}
    {% if flags.WHICH not in ['run','run-operation'] %}{% do return([]) %}{% endif %}
    {% if not execute %}{% do return([]) %}{% endif %}
    {% set query %}
        select
            function_catalog,
            function_schema as schema_name,
            function_name,
            regexp_replace(
                listagg(trim(split_part(arg, ' ', -1)), ',') within group (order by arg),
                '^,',''
            ) as argument_signature
        from (
            select
                function_catalog,
                function_schema,
                function_name,
                trim(split_part(f.value, ' ', -1)) as arg
            from (
                select
                    function_catalog,
                    function_schema,
                    function_name,
                    split(replace(replace(argument_signature, '(', ''), ')', ''), ',') as args
                from information_schema.functions
                where function_owner != '{{ role_name | upper }}'
                  and function_schema in ({{ schema_list }})
            ), lateral flatten(input => args) as f
        )
        group by function_catalog, function_schema, function_name
    {% endset %}
    {% set results = run_query(query) %}
    {% set statements = [] %}
    {% if results and results | length > 0 %}
        {% for r in results %}
            {{ statements.append('grant ownership on function ' ~ target.database ~ '.' ~ r[1] ~ '.' ~ r[2] ~ '(' ~ r[3] ~ ') to role ' ~ role_name ~ ' revoke current grants;') }}
        {% endfor %}
        {% do log('get_grant_functions_ownership_sql: generated ' ~ (statements | length) ~ ' statements', info=True) %}
    {% else %}
        {% do log('get_grant_functions_ownership_sql: no function ownership changes required', info=True) %}
    {% endif %}
    {% do return(statements) %}
{% endmacro %}