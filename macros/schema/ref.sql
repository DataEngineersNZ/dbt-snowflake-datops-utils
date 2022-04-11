{% macro ref(model_name, include_database=false) %}
    {% do return(builtins.ref(model_name).include(database=include_database)) %}
{% endmacro %}
