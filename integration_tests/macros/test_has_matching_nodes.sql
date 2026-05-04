{#
  Test helper: exercises has_matching_nodes with mock node objects.
  Run via: dbt run-operation test_has_matching_nodes
  Returns nothing on success; raises an error on any assertion failure.
#}
{% macro test_has_matching_nodes() %}
    {% set failures = [] %}

    {# ── Build mock nodes representing different config patterns ── #}

    {# 1. Simple function: name match, parameters directly in config #}
    {% set node_simple = {
        "schema": "analytics",
        "name": "my_function",
        "config": {
            "parameters": "p_id varchar, p_name varchar"
        }
    } %}

    {# 2. Function with parameters inside config.meta (the common pattern) #}
    {% set node_meta_params = {
        "schema": "analytics",
        "name": "my_udtf",
        "config": {
            "meta": {
                "parameters": "p_start date, p_end date"
            }
        }
    } %}

    {# 3. Function with override_name inside config.meta #}
    {% set node_override = {
        "schema": "analytics",
        "name": "my_function_manual",
        "config": {
            "meta": {
                "override_name": "my_function",
                "parameters": "p_id varchar"
            }
        }
    } %}

    {# 4. Function with no parameters (parameterless) #}
    {% set node_no_params = {
        "schema": "analytics",
        "name": "my_parameterless_func",
        "config": {}
    } %}

    {# 5. Function with STRING type in parameters (should be normalized to VARCHAR) #}
    {% set node_string_type = {
        "schema": "analytics",
        "name": "my_string_func",
        "config": {
            "meta": {
                "parameters": "p_val string"
            }
        }
    } %}

    {# 6. Function with newlines in parameters #}
    {% set node_newline_params = {
        "schema": "analytics",
        "name": "my_newline_func",
        "config": {
            "meta": {
                "parameters": "p_id varchar,\np_name varchar"
            }
        }
    } %}

    {% set all_nodes = [node_simple, node_meta_params, node_override, node_no_params, node_string_type, node_newline_params] %}

    {# ── Test 1: Match by name with direct config.parameters ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_FUNCTION", "(p_id varchar, p_name varchar)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 1 FAILED: direct config.parameters match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 2: Match by name with config.meta.parameters ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_UDTF", "(p_start date, p_end date)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 2 FAILED: config.meta.parameters match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 3: Match by config.override_name ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "config.override_name", "ANALYTICS", "MY_FUNCTION", "(p_id varchar)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 3 FAILED: config.override_name match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 4: No match - wrong schema ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "WRONG_SCHEMA", "MY_FUNCTION", "(p_id varchar, p_name varchar)"
    ) %}
    {% if result != false %}
        {% do failures.append("Test 4 FAILED: wrong schema expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 5: No match - wrong name ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "NONEXISTENT_FUNC", "(p_id varchar)"
    ) %}
    {% if result != false %}
        {% do failures.append("Test 5 FAILED: wrong name expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 6: No match - wrong arguments ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_FUNCTION", "(p_id integer)"
    ) %}
    {% if result != false %}
        {% do failures.append("Test 6 FAILED: wrong arguments expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 7: Parameterless function match ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_PARAMETERLESS_FUNC", "()"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 7 FAILED: parameterless match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 8: STRING -> VARCHAR normalization ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_STRING_FUNC", "(p_val varchar)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 8 FAILED: string->varchar normalization expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 9: Newline normalization in parameters ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_NEWLINE_FUNC", "(p_id varchar,p_name varchar)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 9 FAILED: newline normalization expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 10: override_name does NOT match by plain name ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_FUNCTION", "(p_id varchar)"
    ) %}
    {# This should match node_simple (p_id varchar, p_name varchar) but NOT with (p_id varchar) - so false #}
    {% if result != false %}
        {% do failures.append("Test 10 FAILED: partial argument mismatch expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 11: Empty nodes list returns false ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        [], "name", "ANALYTICS", "MY_FUNCTION", "(p_id varchar)"
    ) %}
    {% if result != false %}
        {% do failures.append("Test 11 FAILED: empty nodes expected false, got " ~ result) %}
    {% endif %}

    {# ── Report results ── #}
    {% if failures | length > 0 %}
        {% for f in failures %}
            {% do log(f, info=True) %}
        {% endfor %}
        {{ exceptions.raise_compiler_error("has_matching_nodes: " ~ (failures | length) ~ " test(s) failed. See log above.") }}
    {% else %}
        {% do log("has_matching_nodes: all 11 tests passed", info=True) %}
    {% endif %}
{% endmacro %}
