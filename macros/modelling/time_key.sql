{%- macro time_key(TimeKey) -%}
TO_CHAR({{ TimeKey }},'HHMI')
{%- endmacro -%}