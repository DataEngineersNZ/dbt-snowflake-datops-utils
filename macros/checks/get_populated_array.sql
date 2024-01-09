{% macro get_populated_array(col_to_check, col_to_fall_back_on) -%}
    iff(array_size(coalesce({{ col_to_check }}, [])) > 0, {{ col_to_check }}, {{ col_to_fall_back_on }})
{%- endmacro -%}

{% macro get_populated_array_value_as_string(col_to_check, col_to_fall_back_on) -%}
    array_to_string(iff(array_size(coalesce({{ col_to_check }}, [])) > 0, {{ col_to_check }}, {{ col_to_fall_back_on }}), ',')
{%- endmacro -%}

{% macro get_populated_array_value_or_string_as_string(col_to_check, col_to_fall_back_on) -%}
    array_to_string(iff(array_size(coalesce({{ col_to_check }}, [])) > 0, {{ col_to_check }}, [{{ col_to_fall_back_on }}]), ',')
{%- endmacro -%}
