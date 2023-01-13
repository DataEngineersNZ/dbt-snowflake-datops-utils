{%- macro string_to_num(field) -%}
    TO_NUMBER(REPLACE(TO_VARCHAR({{field}}),',', ''))
{%- endmacro -%}
