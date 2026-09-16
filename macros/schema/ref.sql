{% macro ref(model_name, package=none, version=none, include_database=false) %}
    {% if package %}
        {% do return(builtins.ref(model_name, package=package, version=version).include(database=include_database)) %}
    {% else %}
        {% do return(builtins.ref(model_name, version=version).include(database=include_database)) %}
    {% endif %}
{% endmacro %}
