{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {# Get the folder names which will become the schema name #}
        {% set prefix = node.fqn[1:-1]|join('__') %}
        {% set split_name = prefix.split('__') %}
        {# Check if the model does not contain a subfolder (e.g, models created at the MODELS root folder) #}
        {% if split_name[0]|lower == "dm" %}
            {{ split_name[0] | trim }}
        {% elif split_name[0]|lower == "sources" and node.fqn[1:-1]|length == 3 %}
            {{ split_name[1] | trim }}
        {% elif node.fqn[1:-1]|length == 1 %}
            {{ split_name[0] | trim }}
        {% elif node.fqn[1:-1]|length == 2 %}
            {{ split_name[1] | trim }}
        {% else %}
            {{ split_name[2] | trim }}
        {% endif %}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}