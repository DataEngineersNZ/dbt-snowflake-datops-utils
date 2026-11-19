{#
  Integration test: exercises the grant_database_role_* / revoke_database_role_* / apply_database_roles
  macros against a live Snowflake connection.

  Run via: dbt run-operation test_database_role_macros

  Scope note: GRANT INHERITED / REVOKE INHERITED is NOT universally available (confirmed live: it raises
  "Unsupported feature 'INHERITED'" on at least one tested account/edition), and dbt/Jinja macros have no
  try/catch to gracefully skip a run_query() failure. Exercising that specific SQL keyword live here would
  risk breaking this entire test (and CI) on any account/edition where it isn't enabled. This test therefore
  only covers code paths that never emit GRANT/REVOKE INHERITED:
    - create_database_role
    - grant_database_role_schema_privileges
    - grant_database_role_object / revoke_database_role_object (on an existing view from another test model)
    - grant_database_role_to_role
    - apply_database_roles, using only SCHEMA-type `inherited`/`revoke_inherited` entries with
      `include_schemas` set (that combination is documented to route to a direct schema-level grant/revoke,
      not INHERITED, since a schema can't contain other schemas), plus `revoke_objects` and `roles` mapping.
  grant_database_role_to_application and the true GRANT/REVOKE INHERITED code paths are not covered here --
  the former needs a real installed Native App, the latter needs a Snowflake edition/account with inherited
  grants enabled. Both are exercised only via `dbt parse`/`dbt compile` (see dbt-verify), not live execution.

  Returns nothing on success; raises an error on any assertion failure.
#}
{% macro test_database_role_macros() %}
    {% if flags.WHICH not in ['run', 'run-operation'] %}
        {% do log('test_database_role_macros: skipped (context)', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('test_database_role_macros: skipped (compile phase)', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set failures = [] %}
    {% set test_schema = target.schema %}
    {% set role_a = 'ZZ_TEST_DBROLE_PRIMARY' %}
    {% set role_b = 'ZZ_TEST_DBROLE_APPLY' %}

    {# Drop any leftovers from a previous failed run so this test is repeatable. #}
    {% do run_query('drop database role if exists ' ~ target.database ~ '.' ~ role_a ~ ';') %}
    {% do run_query('drop database role if exists ' ~ target.database ~ '.' ~ role_b ~ ';') %}

    {# ── Test 1: create_database_role creates the role ── #}
    {{ dbt_dataengineers_utils.create_database_role([role_a], 'Integration test role for database role macros') }}
    {% set role_check %}
        show database roles like '{{ role_a }}' in database {{ target.database }};
    {% endset %}
    {% set role_rows = run_query(role_check) %}
    {% if role_rows | length == 0 %}
        {% do failures.append('Test 1 FAILED: create_database_role did not create ' ~ role_a) %}
    {% else %}
        {% do log('Test 1 PASSED: create_database_role created ' ~ role_a, info=True) %}
    {% endif %}

    {# ── Test 2: grant_database_role_schema_privileges grants USAGE on test_schema ── #}
    {# Schema identifiers are unquoted in the generated SQL, so Snowflake normalizes/returns them
       uppercase in SHOW output regardless of the case target.schema happens to be configured with. #}
    {% set expected_schema_name = (target.database ~ '.' ~ test_schema) | upper %}
    {{ dbt_dataengineers_utils.grant_database_role_schema_privileges(['USAGE'], [test_schema], [role_a]) }}
    {% set schema_grant_check %}
        show grants to database role {{ target.database }}.{{ role_a }};
    {% endset %}
    {% set schema_grant_rows = run_query(schema_grant_check) %}
    {% set has_schema_usage = false %}
    {% for row in schema_grant_rows %}
        {% if row.privilege == 'USAGE' and row.granted_on == 'SCHEMA' and (row.name | upper) == expected_schema_name %}
            {% set has_schema_usage = true %}
        {% endif %}
    {% endfor %}
    {% if not has_schema_usage %}
        {% do failures.append('Test 2 FAILED: grant_database_role_schema_privileges did not grant USAGE on ' ~ test_schema ~ ' to ' ~ role_a) %}
    {% else %}
        {% do log('Test 2 PASSED: grant_database_role_schema_privileges granted USAGE on ' ~ test_schema, info=True) %}
    {% endif %}

    {# ── Tests 3-4: grant_database_role_object / revoke_database_role_object on an existing view ── #}
    {% set object_query %}
        select table_schema, table_name
        from {{ target.database }}.information_schema.tables
        where table_schema = '{{ test_schema | upper }}'
        and table_type = 'VIEW'
        limit 1
    {% endset %}
    {% set object_rows = run_query(object_query) %}
    {% if object_rows | length > 0 %}
        {% set target_object = object_rows[0][0] ~ '.' ~ object_rows[0][1] %}

        {{ dbt_dataengineers_utils.grant_database_role_object('VIEW', [target_object], ['SELECT'], [role_a]) }}
        {% set object_grant_check %}
            show grants on view {{ target.database }}.{{ target_object }};
        {% endset %}
        {% set object_grant_rows = run_query(object_grant_check) %}
        {% set has_object_select = false %}
        {% for row in object_grant_rows %}
            {% if row.privilege == 'SELECT' and row.granted_to == 'DATABASE_ROLE' and row.grantee_name == role_a %}
                {% set has_object_select = true %}
            {% endif %}
        {% endfor %}
        {% if not has_object_select %}
            {% do failures.append('Test 3 FAILED: grant_database_role_object did not grant SELECT on ' ~ target_object ~ ' to ' ~ role_a) %}
        {% else %}
            {% do log('Test 3 PASSED: grant_database_role_object granted SELECT on ' ~ target_object, info=True) %}
        {% endif %}

        {{ dbt_dataengineers_utils.revoke_database_role_object('VIEW', [target_object], ['SELECT'], [role_a]) }}
        {% set object_grant_rows_after = run_query(object_grant_check) %}
        {% set still_has_object_select = false %}
        {% for row in object_grant_rows_after %}
            {% if row.privilege == 'SELECT' and row.granted_to == 'DATABASE_ROLE' and row.grantee_name == role_a %}
                {% set still_has_object_select = true %}
            {% endif %}
        {% endfor %}
        {% if still_has_object_select %}
            {% do failures.append('Test 4 FAILED: revoke_database_role_object did not revoke SELECT on ' ~ target_object ~ ' from ' ~ role_a) %}
        {% else %}
            {% do log('Test 4 PASSED: revoke_database_role_object revoked SELECT on ' ~ target_object, info=True) %}
        {% endif %}
    {% else %}
        {% do log('Tests 3-4 SKIPPED: no existing table/view found in schema ' ~ test_schema, info=True) %}
    {% endif %}

    {# ── Test 5: grant_database_role_to_role grants role_a to PUBLIC ── #}
    {{ dbt_dataengineers_utils.grant_database_role_to_role(role_a, ['PUBLIC']) }}
    {% set role_grant_check %}
        show grants of database role {{ target.database }}.{{ role_a }};
    {% endset %}
    {% set role_grant_rows = run_query(role_grant_check) %}
    {% set has_public_grant = false %}
    {% for row in role_grant_rows %}
        {% if row.granted_to == 'ROLE' and row.grantee_name == 'PUBLIC' %}
            {% set has_public_grant = true %}
        {% endif %}
    {% endfor %}
    {% if not has_public_grant %}
        {% do failures.append('Test 5 FAILED: grant_database_role_to_role did not grant ' ~ role_a ~ ' to role PUBLIC') %}
    {% else %}
        {% do log('Test 5 PASSED: grant_database_role_to_role granted ' ~ role_a ~ ' to role PUBLIC', info=True) %}
    {% endif %}

    {# ── Test 6: apply_database_roles -- create, SCHEMA+include_schemas grant (direct, not INHERITED),
       revoke_inherited (direct schema revoke, not REVOKE INHERITED), revoke_objects, and roles mapping,
       all via a single payload call. #}
    {% set database_roles_payload = {
        role_b: {
            'comment': 'Integration test role for apply_database_roles',
            'inherited': [
                {'object_type': 'SCHEMA', 'permissions': ['USAGE']}
            ],
            'include_schemas': [test_schema],
            'roles': {target.name: ['PUBLIC']},
            'revoke_inherited': [
                {'object_type': 'SCHEMA', 'permissions': ['MONITOR'], 'include_schemas': [test_schema]}
            ]
        }
    } %}
    {% if object_rows | length > 0 %}
        {% do database_roles_payload[role_b].update({'revoke_objects': [
            {'object_type': 'VIEW', 'objects': [target_object], 'grant_types': ['SELECT']}
        ]}) %}
    {% endif %}
    {{ dbt_dataengineers_utils.apply_database_roles(database_roles_payload) }}

    {% set apply_role_check %}
        show database roles like '{{ role_b }}' in database {{ target.database }};
    {% endset %}
    {% if (run_query(apply_role_check) | length) == 0 %}
        {% do failures.append('Test 6a FAILED: apply_database_roles did not create ' ~ role_b) %}
    {% else %}
        {% do log('Test 6a PASSED: apply_database_roles created ' ~ role_b, info=True) %}
    {% endif %}

    {% set apply_grant_rows = run_query('show grants to database role ' ~ target.database ~ '.' ~ role_b ~ ';') %}
    {% set apply_has_schema_usage = false %}
    {% for row in apply_grant_rows %}
        {% if row.privilege == 'USAGE' and row.granted_on == 'SCHEMA' and (row.name | upper) == expected_schema_name %}
            {% set apply_has_schema_usage = true %}
        {% endif %}
    {% endfor %}
    {% if not apply_has_schema_usage %}
        {% do failures.append('Test 6b FAILED: apply_database_roles did not grant USAGE on ' ~ test_schema ~ ' to ' ~ role_b) %}
    {% else %}
        {% do log('Test 6b PASSED: apply_database_roles granted USAGE on ' ~ test_schema ~ ' via the inherited payload key', info=True) %}
    {% endif %}

    {% set apply_role_grant_rows = run_query('show grants of database role ' ~ target.database ~ '.' ~ role_b ~ ';') %}
    {% set apply_has_public_grant = false %}
    {% for row in apply_role_grant_rows %}
        {% if row.granted_to == 'ROLE' and row.grantee_name == 'PUBLIC' %}
            {% set apply_has_public_grant = true %}
        {% endif %}
    {% endfor %}
    {% if not apply_has_public_grant %}
        {% do failures.append('Test 6c FAILED: apply_database_roles did not grant ' ~ role_b ~ ' to role PUBLIC via the roles payload key') %}
    {% else %}
        {% do log('Test 6c PASSED: apply_database_roles granted ' ~ role_b ~ ' to role PUBLIC via the roles payload key', info=True) %}
    {% endif %}

    {# ── Cleanup: drop both test database roles (also removes all their grants). ── #}
    {% do run_query('drop database role if exists ' ~ target.database ~ '.' ~ role_a ~ ';') %}
    {% do run_query('drop database role if exists ' ~ target.database ~ '.' ~ role_b ~ ';') %}

    {# ── Report results ── #}
    {% if failures | length > 0 %}
        {% for f in failures %}
            {% do log(f, info=True) %}
        {% endfor %}
        {{ exceptions.raise_compiler_error("test_database_role_macros: " ~ (failures | length) ~ " test(s) failed. See log above.") }}
    {% else %}
        {% do log('test_database_role_macros: all tests passed', info=True) %}
    {% endif %}
{% endmacro %}
