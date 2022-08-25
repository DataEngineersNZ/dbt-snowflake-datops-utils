{% macro get_column_data(data) %}
    {% if data is number  %}
        {{ return(data) }}
    {% else %}
        {{ return("'" ~ data ~ "'") }}
    {% endif %}
{% endmacro %}
