{% macro has_matching_nodes(nodes, name_property, sql_object_schema, sql_object_name, sql_arguments ) %}
        {% set matching_nodes = nodes
            | selectattr("schema", "equalto", sql_object_schema | lower)
            | selectattr(name_property, "equalto", sql_object_name | lower)
        %}

        {% for node in matching_nodes %}
            {# Ensure there are no line breaks in the arguments #}
            {% set dbt_arguments = node.config.parameters | lower | replace("string", "varchar") | replace('\n', '') | replace('\r', '') %}

            {% if name_property == "config.override_name" %}
                {% set dbt_signature = (node.schema ~ "." ~ node.config.override_name ~ "(" ~ dbt_arguments ~ ")") | lower %}
            {% else %}
                {% set dbt_signature = (node.schema ~ "." ~ node.name ~ "(" ~ dbt_arguments ~ ")") | lower %}
            {% endif %}

            {% set sql_signature = (sql_object_schema ~ "." ~ sql_object_name ~ sql_arguments) | lower %}
            {% if sql_signature == dbt_signature %}
                 {{ return(true) }}
            {% endif %}
        {% endfor %}
    {{ return(false) }}
{% endmacro %}
