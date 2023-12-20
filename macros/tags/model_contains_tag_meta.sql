
{% macro model_contains_tag_meta(tag_names, model_node) %}
    {% for column in model_node.columns %}
       {% for tag_name in tag_names %}
            {% if tag_name in model_node.columns[column].meta %}
              {{ return(True) }}
    	    {% endif %}
       {% endfor %}
    {% endfor %}
    {{ return(False) }}
{% endmacro %}