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
                {% set dbt_arguments = dbt_dataengineers_utils.collapse_whitespace(
                    (raw_params | default("", true)) | lower | replace("string", "varchar")
                ) %}

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
                   Snowflake information_schema may return signatures with param names
                   e.g. (TARGET_TIMEZONE VARCHAR) while dbt parameters include names and
                   DEFAULT clauses e.g. "target_timezone VARCHAR DEFAULT 'Pacific/Auckland'".
                   Parameters may also contain parenthesised precision e.g. NUMBER(3, 0).
                   Extract just the types from BOTH sides and compare again. #}
                {% set dbt_types = [] %}
                {% set clean_dbt_args = dbt_arguments | trim %}
                {% if clean_dbt_args | length > 0 %}
                    {% for param in dbt_dataengineers_utils.split_params(clean_dbt_args) %}
                        {% set param_type = dbt_dataengineers_utils.extract_param_type(param) %}
                        {% if param_type | length > 0 %}
                            {% do dbt_types.append(param_type) %}
                        {% endif %}
                    {% endfor %}
                {% endif %}

                {# Also extract types-only from the Snowflake side (which may include param names) #}
                {% set sql_types = [] %}
                {% set clean_sql_args = sql_arguments | replace("(", "", 1) %}
                {% if clean_sql_args.endswith(")") %}
                    {% set clean_sql_args = clean_sql_args[:-1] %}
                {% endif %}
                {% set clean_sql_args = clean_sql_args | trim %}
                {% if clean_sql_args | length > 0 %}
                    {% for param in dbt_dataengineers_utils.split_params(clean_sql_args) %}
                        {% set param_type = dbt_dataengineers_utils.extract_param_type(param) %}
                        {% if param_type | length > 0 %}
                            {% do sql_types.append(param_type) %}
                        {% endif %}
                    {% endfor %}
                {% endif %}

                {% if name_property == "config.override_name" %}
                    {% set dbt_types_signature = (node.schema ~ "." ~ node_name ~ "(" ~ dbt_types | join(", ") ~ ")") | lower %}
                    {% set sql_types_signature = (sql_object_schema ~ "." ~ sql_object_name ~ "(" ~ sql_types | join(", ") ~ ")") | lower %}
                {% else %}
                    {% set dbt_types_signature = (node.schema ~ "." ~ node.name ~ "(" ~ dbt_types | join(", ") ~ ")") | lower %}
                    {% set sql_types_signature = (sql_object_schema ~ "." ~ sql_object_name ~ "(" ~ sql_types | join(", ") ~ ")") | lower %}
                {% endif %}

                {% if sql_types_signature == dbt_types_signature %}
                    {{ return(true) }}
                {% endif %}
            {% endif %}
        {% endif %}
    {% endfor %}
    {{ return(false) }}
{% endmacro %}
