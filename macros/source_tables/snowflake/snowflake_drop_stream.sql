{% macro snowflake_drop_stream(stream_relation) %}
   DROP STREAM IF EXISTS {{ stream_relation }}
{% endmacro %}