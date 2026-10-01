{#
  Test helper macros for grants management.
  Run via: dbt run-operation test_grants_helpers
  Returns nothing on success; raises an error on any assertion failure.
#}
{% macro test_grants_helpers() %}
    {% set failures = [] %}

    {# ── Test _grants_normalize_roles ── #}

    {# Test 1: lowercase roles are uppercased #}
    {% set result = dbt_dataengineers_utils._grants_normalize_roles(['analyst', 'developer']) %}
    {% if result != ['ANALYST', 'DEVELOPER'] %}
        {% do failures.append("Test 1 FAILED: lowercase normalization expected ['ANALYST', 'DEVELOPER'], got " ~ result) %}
    {% endif %}

    {# Test 2: mixed-case roles are uppercased #}
    {% set result = dbt_dataengineers_utils._grants_normalize_roles(['Analyst', 'OPS_Support', 'readers_prod']) %}
    {% if result != ['ANALYST', 'OPS_SUPPORT', 'READERS_PROD'] %}
        {% do failures.append("Test 2 FAILED: mixed-case normalization expected ['ANALYST', 'OPS_SUPPORT', 'READERS_PROD'], got " ~ result) %}
    {% endif %}

    {# Test 3: already-uppercase roles stay unchanged #}
    {% set result = dbt_dataengineers_utils._grants_normalize_roles(['ADMIN', 'DATAOPS_ADMIN']) %}
    {% if result != ['ADMIN', 'DATAOPS_ADMIN'] %}
        {% do failures.append("Test 3 FAILED: uppercase passthrough expected ['ADMIN', 'DATAOPS_ADMIN'], got " ~ result) %}
    {% endif %}

    {# Test 4: empty list returns empty list #}
    {% set result = dbt_dataengineers_utils._grants_normalize_roles([]) %}
    {% if result != [] %}
        {% do failures.append("Test 4 FAILED: empty list expected [], got " ~ result) %}
    {% endif %}

    {# Test 5: single role #}
    {% set result = dbt_dataengineers_utils._grants_normalize_roles(['my_Role']) %}
    {% if result != ['MY_ROLE'] %}
        {% do failures.append("Test 5 FAILED: single role expected ['MY_ROLE'], got " ~ result) %}
    {% endif %}

    {# ── Test _grants_format_list ── #}

    {# Test 6: formats a list of values into quoted comma-separated string #}
    {% set result = dbt_dataengineers_utils._grants_format_list(['SCHEMA_A', 'SCHEMA_B']) %}
    {% if result != "'SCHEMA_A', 'SCHEMA_B'" %}
        {% do failures.append("Test 6 FAILED: format_list expected \"'SCHEMA_A', 'SCHEMA_B'\", got " ~ result) %}
    {% endif %}

    {# Test 7: empty list returns empty string #}
    {% set result = dbt_dataengineers_utils._grants_format_list([]) %}
    {% if result != '' %}
        {% do failures.append("Test 7 FAILED: format_list empty expected '', got " ~ result) %}
    {% endif %}

    {# Test 8: single item list #}
    {% set result = dbt_dataengineers_utils._grants_format_list(['PUBLIC']) %}
    {% if result != "'PUBLIC'" %}
        {% do failures.append("Test 8 FAILED: format_list single expected \"'PUBLIC'\", got " ~ result) %}
    {% endif %}

    {# Test 9: escapes single quotes within values #}
    {% set result = dbt_dataengineers_utils._grants_format_list(["it's"]) %}
    {% if result != "'it''s'" %}
        {% do failures.append("Test 9 FAILED: format_list escaping expected \"'it''s'\", got " ~ result) %}
    {% endif %}

    {# ── Test _grants_append_unique ── #}

    {# Test 10: appends unique value #}
    {% set test_list = ['A', 'B'] %}
    {% do dbt_dataengineers_utils._grants_append_unique(test_list, 'C') %}
    {% if test_list != ['A', 'B', 'C'] %}
        {% do failures.append("Test 10 FAILED: append_unique expected ['A', 'B', 'C'], got " ~ test_list) %}
    {% endif %}

    {# Test 11: does not append duplicate #}
    {% set test_list = ['A', 'B', 'C'] %}
    {% do dbt_dataengineers_utils._grants_append_unique(test_list, 'B') %}
    {% if test_list != ['A', 'B', 'C'] %}
        {% do failures.append("Test 11 FAILED: append_unique duplicate expected ['A', 'B', 'C'], got " ~ test_list) %}
    {% endif %}

    {# ── Test case-insensitive role comparisons ── #}

    {# Test 12: normalized role list membership check #}
    {% set roles = dbt_dataengineers_utils._grants_normalize_roles(['analyst', 'Developer']) %}
    {% if 'ANALYST' not in roles %}
        {% do failures.append("Test 12 FAILED: 'ANALYST' should be in normalized roles") %}
    {% endif %}
    {% if 'DEVELOPER' not in roles %}
        {% do failures.append("Test 12b FAILED: 'DEVELOPER' should be in normalized roles") %}
    {% endif %}
    {% if 'analyst' in roles %}
        {% do failures.append("Test 12c FAILED: 'analyst' (lowercase) should NOT be in normalized roles") %}
    {% endif %}

    {# Test 13: grantee_name from Snowflake (uppercase) matches normalized roles #}
    {% set roles = dbt_dataengineers_utils._grants_normalize_roles(['ops_support']) %}
    {% set snowflake_grantee = 'OPS_SUPPORT' %}
    {% if snowflake_grantee not in roles %}
        {% do failures.append("Test 13 FAILED: Snowflake grantee 'OPS_SUPPORT' should match normalized ['ops_support']") %}
    {% endif %}

    {# ── Test _grants_pluralize_object_type ── #}

    {# Test 14: regular type gets a trailing S #}
    {% set result = dbt_dataengineers_utils._grants_pluralize_object_type('TABLE') %}
    {% if result != 'TABLES' %}
        {% do failures.append("Test 14 FAILED: pluralize('TABLE') expected 'TABLES', got " ~ result) %}
    {% endif %}

    {# Test 15: consonant + Y gets IES #}
    {% set result = dbt_dataengineers_utils._grants_pluralize_object_type('POLICY') %}
    {% if result != 'POLICIES' %}
        {% do failures.append("Test 15 FAILED: pluralize('POLICY') expected 'POLICIES', got " ~ result) %}
    {% endif %}

    {# Test 16: multi-word consonant + Y type gets IES #}
    {% set result = dbt_dataengineers_utils._grants_pluralize_object_type('MASKING POLICY') %}
    {% if result != 'MASKING POLICIES' %}
        {% do failures.append("Test 16 FAILED: pluralize('MASKING POLICY') expected 'MASKING POLICIES', got " ~ result) %}
    {% endif %}

    {# Test 17: lowercase input is normalized to uppercase before pluralizing #}
    {% set result = dbt_dataengineers_utils._grants_pluralize_object_type('authentication policy') %}
    {% if result != 'AUTHENTICATION POLICIES' %}
        {% do failures.append("Test 17 FAILED: pluralize('authentication policy') expected 'AUTHENTICATION POLICIES', got " ~ result) %}
    {% endif %}

    {# Test 18: vowel-preceded Y does not trigger the IES rule (e.g. a hypothetical "RELAY" -> "RELAYS") #}
    {% set result = dbt_dataengineers_utils._grants_pluralize_object_type('RELAY') %}
    {% if result != 'RELAYS' %}
        {% do failures.append("Test 18 FAILED: pluralize('RELAY') expected 'RELAYS', got " ~ result) %}
    {% endif %}

    {# Test 19: other common Snowflake object types pluralize with a plain S #}
    {% set result = dbt_dataengineers_utils._grants_pluralize_object_type('FUNCTION') %}
    {% if result != 'FUNCTIONS' %}
        {% do failures.append("Test 19 FAILED: pluralize('FUNCTION') expected 'FUNCTIONS', got " ~ result) %}
    {% endif %}

    {# ── Report results ── #}
    {% if failures | length > 0 %}
        {% for f in failures %}
            {% do log(f, info=True) %}
        {% endfor %}
        {{ exceptions.raise_compiler_error("test_grants_helpers: " ~ (failures | length) ~ " test(s) failed. See log above.") }}
    {% else %}
        {% do log("test_grants_helpers: all 19 tests passed", info=True) %}
    {% endif %}
{% endmacro %}
