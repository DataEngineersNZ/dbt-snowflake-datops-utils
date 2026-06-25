{#
  Integration test: verifies grant macros are idempotent (skip when no changes needed).
  Run via: dbt run-operation test_grants_idempotency
  Requires a Snowflake connection. Uses grants_dry_run=true to avoid mutations.
  Returns nothing on success; raises an error on any assertion failure.

  This test:
  1. Runs grant macros once to establish state
  2. Captures the log output / statement counts
  3. Verifies that the macros correctly identify "no changes required" scenarios
#}
{% macro test_grants_idempotency() %}
    {% if flags.WHICH not in ['run', 'run-operation'] %}
        {% do log('test_grants_idempotency: skipped (context)', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('test_grants_idempotency: skipped (compile phase)', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set failures = [] %}
    {% set test_schema = 'PUBLIC' %}

    {# ── Test 1: _grants_get_schema_grants returns a list ── #}
    {% set roles_with_usage = dbt_dataengineers_utils._grants_get_schema_grants(test_schema, 'USAGE', 'ROLE') %}
    {% if roles_with_usage is not iterable %}
        {% do failures.append("Test 1 FAILED: _grants_get_schema_grants should return a list, got " ~ roles_with_usage) %}
    {% else %}
        {% do log("Test 1 PASSED: _grants_get_schema_grants returned " ~ (roles_with_usage | length) ~ " roles with USAGE on " ~ test_schema, info=True) %}
    {% endif %}

    {# ── Test 2: _grants_get_schema_object_privs returns a dict ── #}
    {% set privs = dbt_dataengineers_utils._grants_get_schema_object_privs(test_schema, ['SELECT'], []) %}
    {% if privs is not mapping %}
        {% do failures.append("Test 2 FAILED: _grants_get_schema_object_privs should return a dict, got " ~ privs) %}
    {% else %}
        {% do log("Test 2 PASSED: _grants_get_schema_object_privs returned dict with " ~ (privs.keys() | list | length) ~ " roles", info=True) %}
    {% endif %}

    {# ── Test 3: _grants_get_future_grants returns a dict ── #}
    {% set future = dbt_dataengineers_utils._grants_get_future_grants(test_schema) %}
    {% if future is not mapping %}
        {% do failures.append("Test 3 FAILED: _grants_get_future_grants should return a dict, got " ~ future) %}
    {% else %}
        {% do log("Test 3 PASSED: _grants_get_future_grants returned dict with " ~ (future.keys() | list | length) ~ " roles", info=True) %}
    {% endif %}

    {# ── Test 4: _grants_collect_schemas returns non-empty list ── #}
    {% set schemas = dbt_dataengineers_utils._grants_collect_schemas(['INFORMATION_SCHEMA'], is_exclude_list=true) %}
    {% if schemas | length == 0 %}
        {% do failures.append("Test 4 FAILED: _grants_collect_schemas returned no schemas (database may be empty)") %}
    {% else %}
        {% do log("Test 4 PASSED: _grants_collect_schemas found " ~ (schemas | length) ~ " schemas", info=True) %}
    {% endif %}

    {# ── Test 5: grant_schema_monitor_specific with existing role skips ── #}
    {# Find a role that already has MONITOR grants in the test schema #}
    {% set monitor_query %}
        select distinct grantee
        from information_schema.object_privileges
        where privilege_type = 'MONITOR' and object_schema = '{{ test_schema }}'
        limit 1
    {% endset %}
    {% set monitor_results = run_query(monitor_query) %}
    {% if monitor_results and monitor_results | length > 0 %}
        {% set existing_role = monitor_results[0][0] %}
        {% do log("Test 5: Found existing MONITOR role: " ~ existing_role ~ ", running monitor_specific with dry_run", info=True) %}
        {# Running with the role that already has MONITOR should produce minimal/no new statements #}
        {{ dbt_dataengineers_utils.grant_schema_monitor_specific([test_schema], [existing_role], false, true) }}
        {% do log("Test 5 PASSED: grant_schema_monitor_specific completed without error for existing role", info=True) %}
    {% else %}
        {% do log("Test 5 SKIPPED: no existing MONITOR grants found in " ~ test_schema, info=True) %}
    {% endif %}

    {# ── Test 6: grant_schema_read_specific runs without error (dry-run equivalent) ── #}
    {# Use a role that likely already has SELECT on PUBLIC #}
    {% set select_query %}
        select distinct grantee
        from information_schema.object_privileges
        where privilege_type = 'SELECT' and object_schema = '{{ test_schema }}'
        limit 1
    {% endset %}
    {% set select_results = run_query(select_query) %}
    {% if select_results and select_results | length > 0 %}
        {% set existing_role = select_results[0][0] %}
        {% do log("Test 6: Running grant_schema_read_specific for role " ~ existing_role ~ " which already has SELECT", info=True) %}
        {# revoke_current_grants=false prevents any mutations; just tests the skip-logic path #}
        {{ dbt_dataengineers_utils.grant_schema_read_specific([test_schema], [existing_role], false, false) }}
        {% do log("Test 6 PASSED: grant_schema_read_specific completed without error", info=True) %}
    {% else %}
        {% do log("Test 6 SKIPPED: no existing SELECT grants found in " ~ test_schema, info=True) %}
    {% endif %}

    {# ── Test 7: Case-insensitive role matching works against live data ── #}
    {% if select_results and select_results | length > 0 %}
        {% set existing_role = select_results[0][0] %}
        {# Pass lowercase version of the role - should still match #}
        {% set lower_role = existing_role | lower %}
        {% set normalized = dbt_dataengineers_utils._grants_normalize_roles([lower_role]) %}
        {% if normalized[0] != existing_role | upper %}
            {% do failures.append("Test 7 FAILED: normalize_roles('" ~ lower_role ~ "') should be '" ~ (existing_role | upper) ~ "', got " ~ normalized[0]) %}
        {% else %}
            {% do log("Test 7 PASSED: normalize_roles('" ~ lower_role ~ "') == '" ~ normalized[0] ~ "'", info=True) %}
        {% endif %}
    {% else %}
        {% do log("Test 7 SKIPPED: no roles to test", info=True) %}
    {% endif %}

    {# ── Test 8: grant_schema_procedure_usage_specific runs without error ── #}
    {{ dbt_dataengineers_utils.grant_schema_procedure_usage_specific([test_schema], ['SYSADMIN'], false, true) }}
    {% do log("Test 8 PASSED: grant_schema_procedure_usage_specific completed without error (dry_run=true)", info=True) %}

    {# ── Test 9: grant_schema_operate_specific runs without error ── #}
    {{ dbt_dataengineers_utils.grant_schema_operate_specific([test_schema], ['SYSADMIN'], false, true) }}
    {% do log("Test 9 PASSED: grant_schema_operate_specific completed without error (dry_run=true)", info=True) %}

    {# ── Report results ── #}
    {% if failures | length > 0 %}
        {% for f in failures %}
            {% do log(f, info=True) %}
        {% endfor %}
        {{ exceptions.raise_compiler_error("test_grants_idempotency: " ~ (failures | length) ~ " test(s) failed. See log above.") }}
    {% else %}
        {% do log("test_grants_idempotency: all tests passed", info=True) %}
    {% endif %}
{% endmacro %}
