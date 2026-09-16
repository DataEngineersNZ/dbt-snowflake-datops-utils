{#
  Integration test: exercises the run_query()-driven clean_* macros (and the
  SHOW-command / SELECT-alias result-row access they rely on) against a live
  Snowflake connection. Added to catch regressions in named-column result access
  and dbt Fusion (dbt 2.0) compatibility.

  Run via: dbt run-operation test_clean_macros

  Tests 1-2 assert directly on the root-cause behaviour that broke previously:
  Snowflake's result-row column-name casing differs between a plain unquoted
  `SELECT ... AS alias` (returned UPPERCASE) and `SHOW <OBJECT>` command output
  (returned lowercase) -- these can genuinely fail if that casing regresses or
  is misused.

  Tests 3-11 are smoke tests: they use dry_run=true throughout, so no DDL is
  ever executed. They only assert that the macros run without raising, since
  asserting on their exact drop-selection output would require provisioning
  known fixture objects (tasks, secrets, functions) in the target database,
  which is out of scope for a dry-run macro test. Returns nothing on success;
  raises an error if any assertion fails or any macro call itself raises.
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
    {% set expected_schema_upper = target.schema | upper %}

    {# ── Test 1: unquoted SELECT alias columns are returned UPPERCASE by Snowflake ── #}
    {% set alias_query %}
        select table_schema from {{ target.database }}.information_schema.tables
        where table_schema = '{{ expected_schema_upper }}' limit 1
    {% endset %}
    {% set alias_rows = run_query(alias_query) %}
    {% if alias_rows | length == 0 %}
        {% do failures.append("Test 1 FAILED: no rows found in information_schema.tables for schema " ~ expected_schema_upper ~ " -- expected at least one model already built by this project") %}
    {% elif alias_rows[0]['TABLE_SCHEMA'] != expected_schema_upper %}
        {% do failures.append("Test 1 FAILED: row['TABLE_SCHEMA'] expected '" ~ expected_schema_upper ~ "', got '" ~ alias_rows[0]['TABLE_SCHEMA'] ~ "'") %}
    {% else %}
        {% do log("Test 1 PASSED: unquoted SELECT alias column TABLE_SCHEMA is uppercase-keyed as expected", info=True) %}
    {% endif %}

    {# ── Test 2: SHOW command output columns are returned lowercase by Snowflake ── #}
    {% set show_query %}SHOW VIEWS IN SCHEMA {{ target.database }}.{{ target.schema }}{% endset %}
    {% set show_rows = run_query(show_query) %}
    {% if show_rows | length == 0 %}
        {% do failures.append("Test 2 FAILED: no rows found from SHOW VIEWS IN SCHEMA " ~ target.schema ~ " -- expected at least one view already built by this project") %}
    {% elif show_rows[0]['schema_name'] != expected_schema_upper %}
        {% do failures.append("Test 2 FAILED: row['schema_name'] expected '" ~ expected_schema_upper ~ "', got '" ~ show_rows[0]['schema_name'] ~ "'") %}
    {% else %}
        {% do log("Test 2 PASSED: SHOW command output column schema_name is lowercase-keyed as expected", info=True) %}
    {% endif %}

    {# ── Test 3: clean_schemas - exercises named-column access on a plain SELECT alias (TABLE_SCHEMA) ── #}
    {% do dbt_dataengineers_utils.clean_schemas(dry_run=true) %}
    {% do log("Test 3 PASSED (smoke): clean_schemas ran without error (dry_run=true)", info=True) %}

    {# ── Test 4: clean_models - exercises named-column access (OBJECT_TYPE, TABLE_SCHEMA, TABLE_NAME) ── #}
    {% do dbt_dataengineers_utils.clean_models(dry_run=true) %}
    {% do log("Test 4 PASSED (smoke): clean_models ran without error (dry_run=true)", info=True) %}

    {# ── Test 5: clean_functions - exercises named-column access (SCHEMA, NAME, ARGUMENT_SIGNATURE, OBJECT_TYPE) ── #}
    {% do dbt_dataengineers_utils.clean_functions(dry_run=true) %}
    {% do log("Test 5 PASSED (smoke): clean_functions ran without error (dry_run=true)", info=True) %}

    {# ── Test 6: clean_data_metric_functions - exercises named-column access (SCHEMA, NAME, ARGUMENT_SIGNATURE) ── #}
    {% do dbt_dataengineers_utils.clean_data_metric_functions(dry_run=true) %}
    {% do log("Test 6 PASSED (smoke): clean_data_metric_functions ran without error (dry_run=true)", info=True) %}

    {# ── Test 7: clean_generic('VIEW') - exercises SHOW command lowercase column access (schema_name, name) ── #}
    {% do dbt_dataengineers_utils.clean_generic('VIEW', dry_run=true) %}
    {% do log("Test 7 PASSED (smoke): clean_generic('VIEW') ran without error (dry_run=true)", info=True) %}

    {# ── Test 8: clean_generic('TASK') - previously used a hardcoded schema_index=4 positional offset ── #}
    {% do dbt_dataengineers_utils.clean_generic('TASK', dry_run=true) %}
    {% do log("Test 8 PASSED (smoke): clean_generic('TASK') ran without error (dry_run=true)", info=True) %}

    {# ── Test 9: clean_generic('SECRET') - previously used a hardcoded schema_index=2 positional offset ── #}
    {% do dbt_dataengineers_utils.clean_generic('SECRET', dry_run=true) %}
    {% do log("Test 9 PASSED (smoke): clean_generic('SECRET') ran without error (dry_run=true)", info=True) %}

    {# ── Test 10: clean_stale_models - exercises the DROP_COMMAND named-column fix. Large `days` avoids matching any real table ── #}
    {% do dbt_dataengineers_utils.clean_stale_models(days=36500, dry_run=true) %}
    {% do log("Test 10 PASSED (smoke): clean_stale_models ran without error (dry_run=true)", info=True) %}

    {# ── Test 11: drop_views_in_schema_for_snapshots - only executes its body when flags.WHICH == 'snapshot',
       so calling it here (flags.WHICH == 'run-operation') is a safe no-op that still verifies the macro compiles ── #}
    {% do dbt_dataengineers_utils.drop_views_in_schema_for_snapshots(target.schema, dry_run=true) %}
    {% do log("Test 11 PASSED (smoke): drop_views_in_schema_for_snapshots ran without error (no-op outside snapshot context)", info=True) %}

    {# ── Report results ── #}
    {% if failures | length > 0 %}
        {% for f in failures %}
            {% do log(f, info=True) %}
        {% endfor %}
        {{ exceptions.raise_compiler_error("test_clean_macros: " ~ (failures | length) ~ " test(s) failed. See log above.") }}
    {% else %}
        {% do log("test_clean_macros: all 11 tests passed", info=True) %}
    {% endif %}
{% endmacro %}
