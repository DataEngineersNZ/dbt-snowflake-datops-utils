{% macro datetime_to_date_dim(col) %}
  TO_CHAR("{{ col }}", 'YYYYMMDD')
{% endmacro %}
