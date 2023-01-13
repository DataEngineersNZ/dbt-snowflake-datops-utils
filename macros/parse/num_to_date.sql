{%- macro num_to_date(date_field) -%}
    TRY_TO_DATE(TO_VARCHAR({{date_field}}),'yyyymmdd')
{%- endmacro -%}
