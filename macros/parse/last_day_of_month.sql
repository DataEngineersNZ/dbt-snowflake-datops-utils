{%- macro last_day_month(s_year, s_month, month_format) -%}
    LAST_DAY(TO_DATE(CONCAT({{ extract_year }}, '-', {{ extract_month }}, '-01'), 'YYYY-{{ month_format }}-DD'), MONTH)
{%- endmacro -%}