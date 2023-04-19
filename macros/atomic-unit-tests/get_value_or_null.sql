{%- macro get_value_or_null(value, inc_quotes) -%}
    {%- if value == null -%}
        {{ "null" }}
    {%- elif value == "null" -%}
        {{ value }}
    {%- elif inc_quotes -%}
        '{{ value }}'
    {%- else -%}
        {{ value }}
    {%- endif -%}
{%- endmacro -%}