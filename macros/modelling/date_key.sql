{% macro date_key(DateKey) -%}
    TO_CHAR({{ DateKey }},'YYYYMMDD')
{% endmacro %}