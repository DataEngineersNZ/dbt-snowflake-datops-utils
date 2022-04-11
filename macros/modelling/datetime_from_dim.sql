{% macro datetime_from_dim(dateKey, timeKey, dt_format = 'YYYYMMDDHHMI') -%}
  TO_TIMESTAMP_NTZ(CONCAT("{{ dateKey }}", "{{ timeKey }}"), '{{dt_format}}')
{% endmacro %}
