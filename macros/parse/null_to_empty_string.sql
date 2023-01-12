{%- macro null_to_empty_string(field) -%}
    COALESCE({{field}}, '')
{%- endmacro -%}
