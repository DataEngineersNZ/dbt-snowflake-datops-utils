# PR #40 Review Fixes + Inherited Grants — Implementation Plan

## Context

PR #40 (`feature/database-role-grants` → `main`) adds 5 database-role grant macros. Sourcery flagged 3 unresolved bugs. The user also wants `GRANT INHERITED` support (confirmed via the Snowflake doc `Using inherited grants`: `GRANT INHERITED <priv> ON ALL <type>S IN {DATABASE <name> | SCHEMA <name>} TO DATABASE ROLE <role>`), at both database and schema scope. Object-level grants already exist (`grant_database_role_object`), so no new macro is needed there — just fix its case-sensitivity bug.

### Sourcery findings on PR #40

1. **`create_database_role.sql:27`** (security) — `comment` isn't escaped before interpolation. A comment containing an apostrophe (e.g. `O'Reilly`) breaks the generated SQL string.
2. **`grant_database_role_object_privileges.sql:30`** (bug) — object type pluralization blindly appends `s` (`{{ object_type }}s`), which breaks for `MASKING POLICY` → `MASKING POLICYS` instead of `MASKING POLICIES`.
3. **`grant_database_role_object.sql:22`** (bug) — the idempotency check compares Snowflake's uppercase `SHOW GRANTS` privilege values against `grant_types` without normalizing case, so lowercase input (`['select']`) causes duplicate `GRANT` statements.

### Existing conventions confirmed by reading the codebase

- Pure-logic helpers live in `macros/grants/_helpers.sql`, prefixed `_grants_*`, unit-tested in `integration_tests/macros/test_grants_helpers.sql` (no Snowflake connection needed — pure Jinja logic).
- Bulk/unconditional grant macros (schema-level, object-privileges) skip pre-checks because `information_schema.object_privileges` can't reliably see `DATABASE_ROLE` grantees, and `GRANT` is inherently idempotent.
- Every macro is documented in `macros/grants/grants.yml` and the README macro table, with CHANGELOG entries and version bumps in `dbt_project.yml`/README kept in sync.
- Guard clauses (`flags.WHICH not in [...]`, `not execute`) and logging style (`====>` prefix, summary log lines) are consistent across all `grant_database_role_*` macros.

## Implementation steps

1. **Fix apostrophe escaping** — `macros/grants/create_database_role.sql`
   Escape single quotes in `comment` before interpolating, matching the escape pattern already used in `_grants_format_list`:
   ```jinja
   {%- if comment %} comment = '{{ comment | replace("'", "''") }}'{% endif -%}
   ```

2. **Add shared pluralization helper** — `macros/grants/_helpers.sql`
   New macro `_grants_pluralize_object_type(object_type)`:
   - Uppercase the type.
   - If it ends in `Y` preceded by a consonant, replace trailing `Y` → `IES` (handles `POLICY` → `POLICIES`, `AUTHENTICATION POLICY` → `AUTHENTICATION POLICIES`, etc.).
   - Otherwise append `S`.
   - Pure function — easy to unit test without a Snowflake connection.

3. **Fix pluralization bug** — `macros/grants/grant_database_role_object_privileges.sql`
   Replace `{{ object_type | lower }}s` with `{{ dbt_dataengineers_utils._grants_pluralize_object_type(object_type) | lower }}`.

4. **Fix case-sensitivity bug** — `macros/grants/grant_database_role_object.sql`
   Normalize `grant_types` to uppercase once near the top of the macro:
   ```jinja
   {% set grant_types = grant_types | map('upper') | list %}
   ```
   before the comparison loop, so lowercase input (`['select']`) correctly matches `SHOW GRANTS` output (`SELECT`). SQL statement text still lowercases the keyword for style consistency (`privilege | lower`).

5. **New macro: inherited grants** — `macros/grants/grant_database_role_inherited_privileges.sql`
   - Signature: `grant_database_role_inherited_privileges(object_type, permissions, database_roles, include_schemas=none, exclude_schemas=none)`.
   - Three mutually-exclusive modes, resolved in this order:
     1. **Explicit include list** — `include_schemas` non-empty → one statement per (schema, role):
        ```sql
        grant inherited <perms> on all <plural_type> in schema {{ target.database }}.<schema> to database role {{ target.database }}.<role>;
        ```
     2. **Exclude list** — `include_schemas` empty/none but `exclude_schemas` is not none → resolve the schema list via the existing `_grants_collect_schemas(exclude_schemas, is_exclude_list=true)` helper (already auto-excludes `INFORMATION_SCHEMA`), then emit the same per-schema statement as above for each resolved schema. This is how "database-level" reach is achieved while still skipping specific schemas, since `GRANT INHERITED ... IN DATABASE` has no exclusion syntax of its own.
     3. **Whole database, no exclusions** — neither param supplied → a single statement per role, no per-schema enumeration:
        ```sql
        grant inherited <perms> on all <plural_type> in database {{ target.database }} to database role {{ target.database }}.<role>;
        ```
   - Uses `_grants_pluralize_object_type`, `_grants_normalize_roles`, and the existing `_grants_collect_schemas` helper (no new schema-collection logic needed).
   - Executed unconditionally (same rationale as sibling bulk macros — no reliable pre-check exists for DATABASE_ROLE inherited grantees; `GRANT INHERITED` is idempotent).
   - Same guard clauses (`flags.WHICH`, `execute`) and logging style as sibling macros.

6. **New macro: prefix-filtered object grants** — `macros/grants/grant_database_role_object_by_prefix.sql`
   Requirement: grant a database role to all objects (views/tables, or any showable type) in a schema — or across the whole database — whose name starts with a given prefix. Neither `GRANT INHERITED` nor the bulk `ON ALL <TYPE>S` syntax supports name-pattern filtering, so this has to resolve actual matching object names first, then delegate to the existing per-object idempotent macro.
   - Signature: `grant_database_role_object_by_prefix(object_type, prefix, grant_types, database_roles, include_schemas=none, exclude_schemas=none)`.
   - Schema resolution reuses the **same three-mode logic** as `grant_database_role_inherited_privileges` (explicit `include_schemas` / `exclude_schemas` via `_grants_collect_schemas` / neither = whole database via `_grants_collect_schemas([], is_exclude_list=true)`), so the "database level" case is just "no schema filters supplied."
   - Discovery step, per resolved schema: `SHOW <plural_type> LIKE '<prefix>%' IN SCHEMA {{ target.database }}.<schema>;` — Snowflake's `SHOW` command supports a `LIKE` pattern clause for every object kind (`SHOW TABLES`, `SHOW VIEWS`, `SHOW FUNCTIONS`, `SHOW STAGES`, etc.), so this one mechanism covers tables/views and any other object type without per-type `information_schema` handling. Uses `_grants_pluralize_object_type` for the keyword.
   - Escapes single quotes in `prefix` before interpolating into the `LIKE` clause (same rationale as fix #1).
   - Collects matched object names into a `schema.object_name` list, then **delegates to the existing `grant_database_role_object` macro** for the actual grant + idempotency check — no duplicated grant logic.
   - If no objects match the prefix in any resolved schema, logs and returns `none` (no-op), consistent with sibling macros' empty-input handling.

7. **Docs** — add `grant_database_role_inherited_privileges` and `grant_database_role_object_by_prefix` entries to `macros/grants/grants.yml` and the README macro table, mirroring the existing entries' format (description, `docs.show: true`, argument list including `exclude_schemas`/`prefix`).

8. **Version/changelog**
   - PR #40 is still open/unmerged (its `1.2.0` bump hasn't been released), so these fixes and additions amend the same unreleased `1.2.0` version rather than bumping to `1.3.0` — no version/README/`dbt_project.yml` version number change needed.
   - Update the existing `v1.2.0` CHANGELOG entry (added by PR #40) to also document: the 3 Sourcery-flagged bug fixes and the two new macros (`grant_database_role_inherited_privileges`, `grant_database_role_object_by_prefix`), keeping the same "Notes" style rationale section used for the rest of that entry.

9. **Unit tests** — `integration_tests/macros/test_grants_helpers.sql`
   Add test cases for `_grants_pluralize_object_type`:
   - Regular type: `TABLE` → `TABLES`
   - Irregular `Y`-ending type: `MASKING POLICY` → `MASKING POLICIES`, `AUTHENTICATION POLICY` → `AUTHENTICATION POLICIES`
   - Mixed-case input passthrough (e.g. `table` → `TABLES`)
   - A vowel-preceded `Y` edge case if one exists among Snowflake object types (to confirm the rule doesn't over-fire)

10. **PR hygiene (optional)** — once fixed, reply to / resolve the 3 Sourcery review threads on PR #40 referencing the commit that fixes each.

## Verification

- `dbt run-operation test_grants_helpers` — confirms new pluralization unit tests pass alongside the existing 13.
- `dbt parse` / `dbt compile` on dbt-core (and dbt Fusion if available locally) — confirms the new macros and edited macros compile cleanly.
- Manual live check against Snowflake (mirroring the PR's existing test plan style): create a throwaway database role, run `grant_database_role_inherited_privileges` in all three modes (explicit `include_schemas`, `exclude_schemas`, and neither/whole-database), verify via `SHOW INHERITED GRANTS IN DATABASE ...` / `SHOW INHERITED GRANTS IN SCHEMA ...` that excluded schemas correctly have no inherited grant while others do, then drop the role.
- Manual live check for `grant_database_role_object_by_prefix`: create a few test tables/views with a shared prefix (e.g. `STG_ORDERS`, `STG_CUSTOMERS`) plus one without it, run the macro with `prefix='STG_'`, verify via `SHOW GRANTS ON TABLE ...` that only the prefix-matching objects received the grant and the non-matching one did not; re-run to confirm idempotency (no duplicate grants logged, since it delegates to `grant_database_role_object`).
- Re-verify the 3 original bug fixes directly:
  - `create_database_role(['TEST_ROLE'], comment="O'Reilly test")` no longer errors.
  - `grant_database_role_object_privileges('MASKING POLICY', ...)` generates `... ON ALL MASKING POLICIES IN SCHEMA ...` (not `POLICYS`).
  - `grant_database_role_object(..., grant_types=['select'], ...)` correctly skips when `SELECT` is already granted (no duplicate `GRANT` statement in the log).

## Example Usages

All six database-role macros, called from a `run-operation` or a model/hook:

```yaml
# dbt_project.yml (on-run-start example) or via: dbt run-operation <macro> --args '{...}'
```

**1. `create_database_role`** — create one or more database roles, optionally with a comment:
```sql
{{ dbt_dataengineers_utils.create_database_role(['ANALYST_DB_ROLE', 'READER_DB_ROLE']) }}

{{ dbt_dataengineers_utils.create_database_role('WRITER_DB_ROLE', comment="Write access for the ETL service account") }}
```

**2. `grant_database_role_schema_privileges`** — grant schema-level privileges to database roles:
```sql
{{ dbt_dataengineers_utils.grant_database_role_schema_privileges(
    permissions=['USAGE', 'MONITOR'],
    schema_names=['ANALYTICS', 'STAGING'],
    database_roles=['ANALYST_DB_ROLE']
) }}
```

**3. `grant_database_role_object_privileges`** — bulk-grant on all objects of a type within schemas:
```sql
{{ dbt_dataengineers_utils.grant_database_role_object_privileges(
    object_type='TABLE',
    schema_names=['ANALYTICS'],
    permissions=['SELECT'],
    database_roles=['ANALYST_DB_ROLE', 'READER_DB_ROLE']
) }}

-- Now correctly pluralizes irregular types after the fix:
{{ dbt_dataengineers_utils.grant_database_role_object_privileges(
    object_type='MASKING POLICY',
    schema_names=['GOVERNANCE'],
    permissions=['APPLY'],
    database_roles=['ANALYST_DB_ROLE']
) }}
```

**4. `grant_database_role_object`** — grant privileges on specific named objects (idempotent, skip-if-held):
```sql
{{ dbt_dataengineers_utils.grant_database_role_object(
    object_type='TABLE',
    objects=['analytics.customers', 'analytics.orders'],
    grant_types=['SELECT', 'REFERENCES'],
    database_roles=['READER_DB_ROLE']
) }}
```

**5. `grant_database_role_to_role`** — attach a database role to one or more account roles:
```sql
{{ dbt_dataengineers_utils.grant_database_role_to_role(
    database_role_name='ANALYST_DB_ROLE',
    role_names=['TRANSFORMER', 'BI_TOOL_ROLE']
) }}
```

**6. `grant_database_role_inherited_privileges`** (new) — inherited grants, all three modes:
```sql
-- Mode 1: explicit schema include list
{{ dbt_dataengineers_utils.grant_database_role_inherited_privileges(
    object_type='TABLE',
    permissions=['SELECT'],
    database_roles=['ANALYST_DB_ROLE'],
    include_schemas=['ANALYTICS', 'STAGING']
) }}

-- Mode 2: whole database except excluded schemas
{{ dbt_dataengineers_utils.grant_database_role_inherited_privileges(
    object_type='TABLE',
    permissions=['SELECT'],
    database_roles=['ANALYST_DB_ROLE'],
    exclude_schemas=['RAW_PII', 'SANDBOX']
) }}

-- Mode 3: whole database, no exclusions (single IN DATABASE statement)
{{ dbt_dataengineers_utils.grant_database_role_inherited_privileges(
    object_type='VIEW',
    permissions=['SELECT'],
    database_roles=['ANALYST_DB_ROLE']
) }}

-- FUNCTION is a valid target type (not on Snowflake's ineligible-object-type list),
-- and USAGE is a valid inherited privilege (not on the ineligible-privilege list).
-- CAUTION: Snowflake explicitly calls out executable objects (functions, procedures,
-- tasks, alerts, services) here -- an inherited USAGE/EXECUTE grant lets the role
-- invoke every current AND future owner's-rights function in scope, including ones
-- added later with no additional grant. Prefer schema scope over database scope for
-- executable object types unless every function in the database should uniformly be
-- invocable by this role.
{{ dbt_dataengineers_utils.grant_database_role_inherited_privileges(
    object_type='FUNCTION',
    permissions=['USAGE'],
    database_roles=['ANALYST_DB_ROLE'],
    include_schemas=['ANALYTICS']
) }}
```

### Object types confirmed ineligible for inherited grants (per Snowflake docs)

Not supported as `GRANT INHERITED ... ON <type> ...` targets: `ORGANIZATION`, `APPLICATION` (consumer-side), `APPLICATION PACKAGE`, `SHARE`, `INTEGRATION`. The macro does not attempt to validate `object_type` against this list -- an unsupported type simply fails at the Snowflake `GRANT` call with a clear SQL error, consistent with how the sibling bulk macros behave today.

Not supported as inherited privileges: `OWNERSHIP`, account-only privileges (e.g. `CREATE WAREHOUSE`, `MANAGE WAREHOUSES`, `MONITOR USAGE`), `USAGE` on `ROLE`/`USER`/`STREAMLIT`/`XMLA_ENDPOINT`.

**7. `grant_database_role_object_by_prefix`** (new) — grant to objects whose name starts with a prefix:
```sql
-- Schema scope: grant SELECT on every TABLE in ANALYTICS starting with "STG_"
{{ dbt_dataengineers_utils.grant_database_role_object_by_prefix(
    object_type='TABLE',
    prefix='STG_',
    grant_types=['SELECT'],
    database_roles=['ANALYST_DB_ROLE'],
    include_schemas=['ANALYTICS']
) }}

-- Database scope, excluding some schemas: grant SELECT on every VIEW starting
-- with "RPT_" anywhere in the database except RAW_PII/SANDBOX
{{ dbt_dataengineers_utils.grant_database_role_object_by_prefix(
    object_type='VIEW',
    prefix='RPT_',
    grant_types=['SELECT'],
    database_roles=['ANALYST_DB_ROLE'],
    exclude_schemas=['RAW_PII', 'SANDBOX']
) }}

-- Full database scope, no exclusions: grant SELECT on every TABLE starting
-- with "DIM_" in any schema
{{ dbt_dataengineers_utils.grant_database_role_object_by_prefix(
    object_type='TABLE',
    prefix='DIM_',
    grant_types=['SELECT'],
    database_roles=['ANALYST_DB_ROLE']
) }}
```
This macro discovers matching object names via `SHOW <TYPE>S LIKE '<prefix>%' IN SCHEMA ...` per resolved schema, then delegates the actual grant + idempotency check to the existing `grant_database_role_object` macro (so re-running it is a no-op once granted, and it correctly skips objects that already have the privilege via any prior direct or bulk grant).

## Critical Files

- `macros/grants/_helpers.sql` — add `_grants_pluralize_object_type` shared helper
- `macros/grants/create_database_role.sql` — apostrophe escaping fix
- `macros/grants/grant_database_role_object.sql` — case-normalization fix; also becomes the delegate target for `grant_database_role_object_by_prefix`
- `macros/grants/grant_database_role_object_privileges.sql` — use new pluralize helper
- `macros/grants/grant_database_role_inherited_privileges.sql` — new macro (to be created)
- `macros/grants/grant_database_role_object_by_prefix.sql` — new macro (to be created)
- `macros/grants/grants.yml`, `README.md`, `CHANGELOG.md`, `dbt_project.yml` — docs/version updates
