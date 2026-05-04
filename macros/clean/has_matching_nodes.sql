{% macro has_matching_nodes(nodes, name_property, sql_object_schema, sql_object_name, sql_arguments ) %}
    {% for node in nodes %}
        {# Match schema first #}
        {% if node.schema | lower == sql_object_schema | lower %}

            {# Resolve the name to compare based on name_property #}
            {% if name_property == "config.override_name" %}
                {% set node_name = node.config.get("meta", {}).get("override_name", node.config.get("override_name", "")) %}
            {% else %}
                {% set node_name = node[name_property] | default("") %}
            {% endif %}

            {% if node_name | lower == sql_object_name | lower %}
                {# Resolve parameters: try config.meta.parameters, then config.parameters, then '' #}
                {% set raw_params = node.config.get("meta", {}).get("parameters", node.config.get("parameters", "")) %}
                {% set dbt_arguments = (raw_params | default("", true)) | lower | replace("string", "varchar") | replace('\n', '') | replace('\r', '') %}

                {% if name_property == "config.override_name" %}
                    {% set dbt_signature = (node.schema ~ "." ~ node_name ~ "(" ~ dbt_arguments ~ ")") | lower %}
                {% else %}
                    {% set dbt_signature = (node.schema ~ "." ~ node.name ~ "(" ~ dbt_arguments ~ ")") | lower %}
                {% endif %}

                {% set sql_signature = (sql_object_schema ~ "." ~ sql_object_name ~ sql_arguments) | lower %}
                {% if sql_signature == dbt_signature %}
                    {{ return(true) }}
                {% endif %}
            {% endif %}
        {% endif %}
    {% endfor %}
    {{ return(false) }}
{% endmacro %}
