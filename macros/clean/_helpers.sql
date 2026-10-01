{#
  Helper macros for clean_functions / has_matching_nodes.
#}


{# ── _clean_scope_nodes_to_current_project ──
   Optionally restricts a list of graph nodes to only those defined in the current/root dbt
   project (node.package_name == project_name), excluding nodes compiled from installed packages
   (dependencies). When current_project_only is false (the default used by all clean_* macros),
   nodes are returned unfiltered, so any package-defined model/seed/snapshot still protects a
   matching Snowflake object from cleanup -- this preserves pre-existing behavior.
   When current_project_only is true, objects that exist in the database solely because an
   installed package materializes a model with that name are treated as orphaned, just like any
   other unmanaged object. #}
{% macro _clean_scope_nodes_to_current_project(nodes, current_project_only=False) %}
    {% if current_project_only %}
        {{ return(nodes | selectattr("package_name", "equalto", project_name) | list) }}
    {% else %}
        {{ return(nodes) }}
    {% endif %}
{% endmacro %}


{# ── collapse_whitespace ──
   Replace all runs of whitespace (spaces, tabs, newlines) with a single space and trim.
   Python's str.split() with no args splits on any whitespace and discards empties,
   so joining the result reliably collapses arbitrary whitespace runs. #}
{% macro collapse_whitespace(value) %}
    {{ return(value.split() | join(' ')) }}
{% endmacro %}


{# ── split_params ──
   Split a parameter string by commas, respecting parentheses.
   e.g. "p_id NUMBER(3, 0), p_name VARCHAR" -> ["p_id NUMBER(3, 0)", "p_name VARCHAR"]
   Plain comma-split would incorrectly break inside NUMBER(3, 0). #}
{% macro split_params(params_str) %}
    {% set result = [] %}
    {% set ns = namespace(current='', depth=0) %}
    {% for char in params_str %}
        {% if char == '(' %}
            {% set ns.depth = ns.depth + 1 %}
            {% set ns.current = ns.current ~ char %}
        {% elif char == ')' %}
            {% set ns.depth = ns.depth - 1 %}
            {% set ns.current = ns.current ~ char %}
        {% elif char == ',' and ns.depth == 0 %}
            {% do result.append(ns.current | trim) %}
            {% set ns.current = '' %}
        {% else %}
            {% set ns.current = ns.current ~ char %}
        {% endif %}
    {% endfor %}
    {# Append the last parameter #}
    {% if ns.current | trim | length > 0 %}
        {% do result.append(ns.current | trim) %}
    {% endif %}
    {{ return(result) }}
{% endmacro %}


{# ── extract_param_type ──
   Given a single parameter string such as:
     "target_timezone varchar default 'Pacific/Auckland'"
     "p_amount number(15, 2) default 0"
     "varchar"                         (type-only, no name)
     "number(3, 0)"                    (type-only with precision)
   Return just the type portion, e.g. "varchar", "number(15, 2)", "number(3, 0)".

   Strategy:
     1. Collapse whitespace so tokens are cleanly separated.
     2. If only one token -> it IS the type (Snowflake type-only format).
     3. If two or more -> first token is the param name.
        Everything from the second token up to (but not including) "default" is the type.
   This handles multi-word / parenthesised types correctly. #}
{% macro extract_param_type(param_str) %}
    {% set cleaned = dbt_dataengineers_utils.collapse_whitespace(param_str) %}
    {% set parts = cleaned.split(' ') %}

    {% if parts | length == 0 or (parts | length == 1 and parts[0] | length == 0) %}
        {{ return('') }}
    {% elif parts | length == 1 %}
        {# Type-only (no param name) #}
        {{ return(parts[0]) }}
    {% else %}
        {# If the first token contains '(' it is a type with precision (e.g. "number(15, 2)")
           not a param name, so reassemble all tokens as the type. #}
        {% if '(' in parts[0] %}
            {% set type_parts = [] %}
            {% for token in parts %}
                {% if token | lower == 'default' %}
                    {{ return(type_parts | join(' ')) }}
                {% else %}
                    {% do type_parts.append(token) %}
                {% endif %}
            {% endfor %}
            {{ return(type_parts | join(' ')) }}
        {% else %}
            {# First token is the param name; collect type tokens until we hit "default" #}
            {% set type_parts = [] %}
            {% for token in parts[1:] %}
                {% if token | lower == 'default' %}
                    {{ return(type_parts | join(' ')) }}
                {% else %}
                    {% do type_parts.append(token) %}
                {% endif %}
            {% endfor %}
            {{ return(type_parts | join(' ')) }}
        {% endif %}
    {% endif %}
{% endmacro %}
