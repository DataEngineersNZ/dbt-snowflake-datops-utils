{#
  Integration test: exercises the run_query()-driven clean_* macros (and the
  SHOW-command / SELECT-alias result-row access they rely on) against a live
  Snowflake connection. Added to catch regressions in named-column result access
  and dbt Fusion (dbt 2.0) compatibility.

  Run via: dbt run-operation test_clean_macros
  Uses dry_run=true throughout, so no DDL is ever executed - these macros only
  ever log the statements they would run. Returns nothing on success; raises
  an error if any macro call itself raises.
#}
{% macro test_clean_macros() %}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('test_clean_macros: skipped (context)', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('test_clean_macros: skipped (compile phase)', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set failures = [] %}

    {# ── Test 1: clean_schemas - exercises named-column access on a plain SELECT alias (TABLE_SCHEMA) ── #}
    {% do dbt_dataengineers_utils.clean_schemas(dry_run=true) %}
    {% do log("Test 1 PASSED: clean_schemas ran without error (dry_run=true)", info=True) %}

    {# ── Test 2: clean_models - exercises named-column access (OBJECT_TYPE, TABLE_SCHEMA, TABLE_NAME) ── #}
    {% do dbt_dataengineers_utils.clean_models(dry_run=true) %}
    {% do log("Test 2 PASSED: clean_models ran without error (dry_run=true)", info=True) %}

    {# ── Test 3: clean_functions - exercises named-column access (SCHEMA, NAME, ARGUMENT_SIGNATURE, OBJECT_TYPE) ── #}
    {% do dbt_dataengineers_utils.clean_functions(dry_run=true) %}
    {% do log("Test 3 PASSED: clean_functions ran without error (dry_run=true)", info=True) %}

    {# ── Test 4: clean_data_metric_functions - exercises named-column access (SCHEMA, NAME, ARGUMENT_SIGNATURE) ── #}
    {% do dbt_dataengineers_utils.clean_data_metric_functions(dry_run=true) %}
    {% do log("Test 4 PASSED: clean_data_metric_functions ran without error (dry_run=true)", info=True) %}

    {# ── Test 5: clean_generic('VIEW') - exercises SHOW command lowercase column access (schema_name, name) ── #}
    {% do dbt_dataengineers_utils.clean_generic('VIEW', dry_run=true) %}
    {% do log("Test 5 PASSED: clean_generic('VIEW') ran without error (dry_run=true)", info=True) %}

    {# ── Test 6: clean_generic('TASK') - previously used a hardcoded schema_index=4 positional offset ── #}
    {% do dbt_dataengineers_utils.clean_generic('TASK', dry_run=true) %}
    {% do log("Test 6 PASSED: clean_generic('TASK') ran without error (dry_run=true)", info=True) %}

    {# ── Test 7: clean_generic('SECRET') - previously used a hardcoded schema_index=2 positional offset ── #}
    {% do dbt_dataengineers_utils.clean_generic('SECRET', dry_run=true) %}
    {% do log("Test 7 PASSED: clean_generic('SECRET') ran without error (dry_run=true)", info=True) %}

    {# ── Test 8: clean_stale_models - exercises the DROP_COMMAND named-column fix. Large `days` avoids matching any real table ── #}
    {% do dbt_dataengineers_utils.clean_stale_models(days=36500, dry_run=true) %}
    {% do log("Test 8 PASSED: clean_stale_models ran without error (dry_run=true)", info=True) %}

    {# ── Test 9: drop_views_in_schema_for_snapshots - only executes its body when flags.WHICH == 'snapshot',
       so calling it here (flags.WHICH == 'run-operation') is a safe no-op that still verifies the macro compiles ── #}
    {% do dbt_dataengineers_utils.drop_views_in_schema_for_snapshots(target.schema, dry_run=true) %}
    {% do log("Test 9 PASSED: drop_views_in_schema_for_snapshots ran without error (no-op outside snapshot context)", info=True) %}

    {# ── Report results ── #}
    {% if failures | length > 0 %}
        {% for f in failures %}
            {% do log(f, info=True) %}
        {% endfor %}
        {{ exceptions.raise_compiler_error("test_clean_macros: " ~ (failures | length) ~ " test(s) failed. See log above.") }}
    {% else %}
        {% do log("test_clean_macros: all 9 tests passed", info=True) %}
    {% endif %}
{% endmacro %}
