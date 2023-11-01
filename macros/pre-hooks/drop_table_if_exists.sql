{% macro drop_table_if_exists() %}
    {% set sql -%}
    execute immediate
    $$
    begin
        if ((
                select distinct table_name
                from {{ this.database }}.information_schema.tables
                where upper(table_name) = upper('{{ this.name }}')
                and upper(table_type) = 'BASE TABLE') is not null)
            then
                drop table if exists {{ this }};
        end if;
    end
    $$;
    {%- endset %}
    {% do run_query(sql) %}
{% endmacro %}
