{#
  Test helper: exercises is_docs_generate_invocation (the dbt-docs-generate detector used by
  depends_on_ref/depends_on_source) with mocked flags.WHICH + invocation_command combinations.
  Pure Jinja logic -- no live Snowflake state required.
  Run via: dbt run-operation test_is_docs_generate_invocation
  Returns nothing on success; raises an error on any assertion failure.
#}
{% macro test_is_docs_generate_invocation() %}
    {% set failures = [] %}

    {# ── Test 1: dbt-core reports flags.WHICH == 'generate' directly ── #}
    {% set result = dbt_dataengineers_utils.is_docs_generate_invocation('generate', 'dbt docs generate') %}
    {% if result != true %}
        {% do failures.append("Test 1 FAILED: dbt-core WHICH='generate' expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 2: dbt Fusion reports flags.WHICH == 'compile' for docs generate too -- must fall back to argv parsing ── #}
    {% set result = dbt_dataengineers_utils.is_docs_generate_invocation('compile', '/usr/local/bin/dbt docs generate') %}
    {% if result != true %}
        {% do failures.append("Test 2 FAILED: Fusion docs generate (absolute path exe) expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 3: Windows dbt.exe with trailing flags after the subcommand ── #}
    {% set result = dbt_dataengineers_utils.is_docs_generate_invocation('compile', 'dbt.exe docs generate --profiles-dir .') %}
    {% if result != true %}
        {% do failures.append("Test 3 FAILED: dbt.exe docs generate with trailing flags expected true, got " ~ result) %}
    {% endif %}

    {# ── Test 4: adversarial case -- 'docs generate' text appears inside a --vars value, must NOT false-positive ── #}
    {% set result = dbt_dataengineers_utils.is_docs_generate_invocation('compile', 'dbt run --vars {"note":"docs generate"}') %}
    {% if result != false %}
        {% do failures.append("Test 4 FAILED: 'docs generate' inside --vars value expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 5: plain dbt compile is not docs generate ── #}
    {% set result = dbt_dataengineers_utils.is_docs_generate_invocation('compile', 'dbt compile') %}
    {% if result != false %}
        {% do failures.append("Test 5 FAILED: dbt compile expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 6: plain dbt build is not docs generate ── #}
    {% set result = dbt_dataengineers_utils.is_docs_generate_invocation('build', 'dbt build') %}
    {% if result != false %}
        {% do failures.append("Test 6 FAILED: dbt build expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 7: plain dbt run is not docs generate ── #}
    {% set result = dbt_dataengineers_utils.is_docs_generate_invocation('run', 'dbt run') %}
    {% if result != false %}
        {% do failures.append("Test 7 FAILED: dbt run expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 8: empty/missing invocation_command (e.g. key absent from invocation_args_dict) with a non-'generate' WHICH ── #}
    {% set result = dbt_dataengineers_utils.is_docs_generate_invocation('compile', '') %}
    {% if result != false %}
        {% do failures.append("Test 8 FAILED: empty invocation_command expected false, got " ~ result) %}
    {% endif %}

    {# ── Test 9: 'docs' and 'generate' present but not adjacent/ordered as the actual subcommand ── #}
    {% set result = dbt_dataengineers_utils.is_docs_generate_invocation('compile', 'dbt run --select generate_docs_helper') %}
    {% if result != false %}
        {% do failures.append("Test 9 FAILED: unrelated tokens containing 'generate'/'docs' expected false, got " ~ result) %}
    {% endif %}

    {# ── Report results ── #}
    {% if failures | length > 0 %}
        {% for f in failures %}
            {% do log(f, info=True) %}
        {% endfor %}
        {{ exceptions.raise_compiler_error("is_docs_generate_invocation: " ~ (failures | length) ~ " test(s) failed. See log above.") }}
    {% else %}
        {% do log("is_docs_generate_invocation: all 9 tests passed", info=True) %}
    {% endif %}
{% endmacro %}
