{%- macro datetime_from_dim(dateKey, timeKey, dt_format = 'YYYYMMDDHHMI') -%}
TO_TIMESTAMP_NTZ(CONCAT(TO_CHAR({{ dateKey }}), TO_CHAR({{ timeKey }})), '{{dt_format}}')
{%- endmacro -%}
