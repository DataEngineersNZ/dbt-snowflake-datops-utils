{% macro drop_view_if_exists() %}
    {% set sql -%}
    execute immediate
    $$
    begin
        if ((
                select distinct table_name
                from {{ this.database }}.information_schema.views
                where upper(table_name) = upper('{{ this.name }}') ) is not null)
            then
                drop view if exists {{ this }};
        end if;
    end
    $$;
    {%- endset %}
    {% do run_query(sql) %}
{% endmacro %}