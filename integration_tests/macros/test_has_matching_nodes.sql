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

    {# 7. Function with DEFAULT clause in parameters (UDTF pattern) #}
    {% set node_default_param = {
        "schema": "m3",
        "name": "udtf_get_all_active_bank_accounts",
        "config": {
            "meta": {
                "parameters": "target_timezone STRING DEFAULT 'Pacific/Auckland'"
            }
        }
    } %}

    {# 8. Function with multiple params including DEFAULT clauses #}
    {% set node_multi_default = {
        "schema": "analytics",
        "name": "my_multi_default_func",
        "config": {
            "parameters": "p_start date, p_timezone string DEFAULT 'UTC', p_limit number DEFAULT 100"
        }
    } %}

    {# 9. Function with multi-line parameters (YAML block scalar style) and DEFAULT, in config.meta #}
    {% set node_multiline_default = {
        "schema": "m3",
        "name": "udtf_multiline_params",
        "config": {
            "meta": {
                "parameters": "p_company  NUMBER,\n  p_timezone  STRING  DEFAULT 'Pacific/Auckland',\n  p_active  BOOLEAN  DEFAULT TRUE"
            }
        }
    } %}

    {# 10. Function with multi-line params directly in config (not under meta) #}
    {% set node_direct_multiline = {
        "schema": "analytics",
        "name": "my_direct_multiline_func",
        "config": {
            "parameters": "p_id  varchar,\n\tp_name\tvarchar"
        }
    } %}

    {# 11. Function with compound types including precision in parentheses #}
    {% set node_compound_types = {
        "schema": "analytics",
        "name": "my_compound_func",
        "config": {
            "parameters": "p_amount NUMBER(15, 2), p_name VARCHAR(100) DEFAULT 'test', p_rate NUMBER(4, 2)"
        }
    } %}

    {# 12. Function with extreme whitespace (many consecutive spaces/tabs) #}
    {% set node_extreme_ws = {
        "schema": "analytics",
        "name": "my_extreme_ws_func",
        "config": {
            "meta": {
                "parameters": "p_id          varchar,\n\t\t\t  p_name          varchar"
            }
        }
    } %}

    {% set all_nodes = [node_simple, node_meta_params, node_override, node_no_params, node_string_type, node_newline_params, node_default_param, node_multi_default, node_multiline_default, node_direct_multiline, node_compound_types, node_extreme_ws] %}

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
        all_nodes, "name", "ANALYTICS", "MY_NEWLINE_FUNC", "(p_id varchar, p_name varchar)"
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

    {# ── Test 12: DEFAULT clause - Snowflake type-only signature matches dbt params with DEFAULT ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "M3", "UDTF_GET_ALL_ACTIVE_BANK_ACCOUNTS", "(VARCHAR)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 12 FAILED: DEFAULT clause type-only match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 13: DEFAULT clause - full signature still matches when Snowflake includes names ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "M3", "UDTF_GET_ALL_ACTIVE_BANK_ACCOUNTS", "(target_timezone varchar default 'pacific/auckland')"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 13 FAILED: DEFAULT clause full signature match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 14: Multiple params with DEFAULT - type-only match ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_MULTI_DEFAULT_FUNC", "(DATE, VARCHAR, NUMBER)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 14 FAILED: multi-param DEFAULT type-only match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 15: DEFAULT clause - wrong type should not match ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "M3", "UDTF_GET_ALL_ACTIVE_BANK_ACCOUNTS", "(NUMBER)"
    ) %}
    {% if result != false %}
        {% do failures.append("Test 15 FAILED: DEFAULT clause wrong type expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 16: Multi-line params with DEFAULT in meta - type-only match ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "M3", "UDTF_MULTILINE_PARAMS", "(NUMBER, VARCHAR, BOOLEAN)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 16 FAILED: multi-line meta params type-only match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 17: Multi-line params with tabs in direct config - type-only match ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_DIRECT_MULTILINE_FUNC", "(VARCHAR, VARCHAR)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 17 FAILED: multi-line tab params type-only match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 18: Multi-line params with extra spaces - full signature match ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_DIRECT_MULTILINE_FUNC", "(p_id varchar, p_name varchar)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 18 FAILED: multi-line full signature match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 19: Compound types with precision - type-only match ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_COMPOUND_FUNC", "(NUMBER(15, 2), VARCHAR(100), NUMBER(4, 2))"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 19 FAILED: compound types type-only match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 20: Compound types - full signature match (no DEFAULT) ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_COMPOUND_FUNC", "(p_amount number(15, 2), p_name varchar(100) default 'test', p_rate number(4, 2))"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 20 FAILED: compound types full signature match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 21: Extreme whitespace - type-only match ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_EXTREME_WS_FUNC", "(VARCHAR, VARCHAR)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 21 FAILED: extreme whitespace type-only match expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 22: Extreme whitespace - full signature match ── #}
    {% set result = dbt_dataengineers_utils.has_matching_nodes(
        all_nodes, "name", "ANALYTICS", "MY_EXTREME_WS_FUNC", "(p_id varchar, p_name varchar)"
    ) %}
    {% if result != true %}
        {% do failures.append("Test 22 FAILED: extreme whitespace full signature match expected true, got " ~ result) %}
    {% endif %}

    {# ── Report results ── #}
    {% if failures | length > 0 %}
        {% for f in failures %}
            {% do log(f, info=True) %}
        {% endfor %}
        {{ exceptions.raise_compiler_error("has_matching_nodes: " ~ (failures | length) ~ " test(s) failed. See log above.") }}
    {% else %}
        {% do log("has_matching_nodes: all 22 tests passed", info=True) %}
    {% endif %}
{% endmacro %}
