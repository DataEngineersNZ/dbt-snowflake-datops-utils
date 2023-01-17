{%- macro first_day_of_month(s_year, s_month, month_format) -%}
    TO_DATE(CONCAT({{ extract_year }}, '-', {{ extract_month }}, '-01'), 'YYYY-{{ month_format }}-DD')
{%- endmacro -%}
