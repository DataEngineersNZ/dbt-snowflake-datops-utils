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
                {% set dbt_arguments = (raw_params | default("", true)) | lower | replace("string", "varchar") | replace('\n', ' ') | replace('\r', '') | replace('\t', ' ') %}
                {# Collapse consecutive spaces left over from newline/tab replacement #}
                {% set dbt_arguments = dbt_arguments | replace('     ', ' ') | replace('    ', ' ') | replace('   ', ' ') | replace('  ', ' ') | trim %}

                {% if name_property == "config.override_name" %}
                    {% set dbt_signature = (node.schema ~ "." ~ node_name ~ "(" ~ dbt_arguments ~ ")") | lower %}
                {% else %}
                    {% set dbt_signature = (node.schema ~ "." ~ node.name ~ "(" ~ dbt_arguments ~ ")") | lower %}
                {% endif %}

                {% set sql_signature = (sql_object_schema ~ "." ~ sql_object_name ~ sql_arguments) | lower %}
                {% if sql_signature == dbt_signature %}
                    {{ return(true) }}
                {% endif %}

                {# ── Fallback: compare types-only signatures ──
                   Snowflake information_schema returns type-only signatures e.g. (VARCHAR)
                   while dbt parameters may include names and DEFAULT clauses e.g.
                   "target_timezone VARCHAR DEFAULT 'Pacific/Auckland'".
                   Parameters may also span multiple lines in YAML/SQL config.
                   Extract just the types from the dbt side and compare again. #}
                {% set dbt_types = [] %}
                {% set clean_dbt_args = dbt_arguments | replace("(", "") | replace(")", "") | trim %}
                {% if clean_dbt_args | length > 0 %}
                    {# Split parameters by comma, then extract the type (second word) from each #}
                    {% for param in clean_dbt_args.split(',') %}
                        {# Split by space and filter out empty parts from consecutive whitespace #}
                        {% set parts = [] %}
                        {% for p in (param | trim).split(' ') %}
                            {% if p | trim | length > 0 %}
                                {% do parts.append(p | trim) %}
                            {% endif %}
                        {% endfor %}
                        {% if parts | length >= 2 %}
                            {% do dbt_types.append(parts[1]) %}
                        {% elif parts | length == 1 and parts[0] | length > 0 %}
                            {# Parameter is already type-only (no name prefix) #}
                            {% do dbt_types.append(parts[0]) %}
                        {% endif %}
                    {% endfor %}
                {% endif %}

                {% if name_property == "config.override_name" %}
                    {% set dbt_types_signature = (node.schema ~ "." ~ node_name ~ "(" ~ dbt_types | join(", ") ~ ")") | lower %}
                {% else %}
                    {% set dbt_types_signature = (node.schema ~ "." ~ node.name ~ "(" ~ dbt_types | join(", ") ~ ")") | lower %}
                {% endif %}

                {% if sql_signature == dbt_types_signature %}
                    {{ return(true) }}
                {% endif %}
            {% endif %}
        {% endif %}
    {% endfor %}
    {{ return(false) }}
{% endmacro %}
