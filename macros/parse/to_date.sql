{%- macro to_date(s_date, date_format) -%}
    TO_DATE({{ s_date }}), '{{ date_format }}')
{%- endmacro -%}