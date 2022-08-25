{% macro create_select_row(columns, values) %}
    {% set stm = namespace(value="SELECT ") %}
    {% for column in columns %}
        {%- set stm.value = stm.value ~ get_column_data(values[loop.index -1]) ~ " AS " ~ column.name -%}
        {% if not loop.last %}
            {%- set stm.value = stm.value ~ ", " -%}
        {% endif %}
    {% endfor %}
    {{ return(stm.value) }}
{% endmacro %}
