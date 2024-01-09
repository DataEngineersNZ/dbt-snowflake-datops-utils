{% macro get_populated_numeric_value(col_to_check, col_to_fall_back_on) -%}
    coalesce(iff(coalesce({{ col_to_check }}, 0) > 0, {{ col_to_check }}, {{ col_to_fall_back_on }}), 0)
{%- endmacro -%}

{% macro get_populated_string_value(col_to_check, col_to_fall_back_on) -%}
    coalesce(iff(len(coalesce({{ col_to_check }}, "")) > 0, {{ col_to_check }}, {{ col_to_fall_back_on }}), "")
{%- endmacro -%}