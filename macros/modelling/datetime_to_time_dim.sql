{% macro datetime_to_time_dim(col) %}
  TO_CHAR("{{ col }}", 'HHMI')
{% endmacro %}
