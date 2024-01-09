{% macro string_epoch_to_timestamp_ltz(given_date) -%}
    to_timestamp_ltz(replace(replace({{ given_date }}, '/Date(', ''), '+0000)/', ''))
{% endmacro %}

{% macro string_epoch_to_timestamp_ntz(given_date) -%}
    to_timestamp_ntz(replace(replace({{ given_date }}, '/Date(', ''), '+0000)/', ''))
{% endmacro %}