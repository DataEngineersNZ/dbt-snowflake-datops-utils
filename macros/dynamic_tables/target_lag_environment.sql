{% macro target_lag_environment(duration_prod, duration_test, duration_other) %}
{% set lag = duration_prod if target.name == "prod" else duration_test if target.name == "test" else duration_other %}
{{ return(lag) }}
{% endmacro %}