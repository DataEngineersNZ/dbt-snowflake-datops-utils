# Agent Instructions

Guidance for AI coding agents (and humans) working in this repo.

## Making a change

1. Work on a new branch — never commit directly to `main`.
2. Implement the change, following existing macro patterns (see sibling macros in the same directory before writing new SQL/Jinja).
3. Run the `dbt-verify` subagent (or equivalent manual check) before considering the change done.

## Every change that affects package behavior MUST also update

Version numbers and docs are **not updated automatically** — do all of these in the same change:

1. **`CHANGELOG.md`**
   - Add a new `## vX.Y.Z - YYYY-MM-DD - <short title>` section at the top (above the previous version), with `### Added` / `### Fixed` / `### Changed` / `### Notes` subsections as applicable.
   - Bump the version per semver: `MAJOR` for breaking changes, `MINOR` for new backward-compatible features, `PATCH` for bug fixes.
2. **`dbt_project.yml`** — bump the `version:` field to match the new CHANGELOG version.
3. **`README.md`** — this file hardcodes the version in two places, both must match the new version:
   - The `- **Version**: X.Y.Z` line near the top.
   - The `revision: "X.Y.Z"` line inside the `packages.yml` install snippet.
   - Also check `README.md` for a macro reference table entry if a macro's signature, name, or description changed, or a new macro was added.
4. **`macros/**/*.yml`** (e.g. `macros/tasks/tasks.yml`) — update macro `description`/`arguments` docs if a macro's signature or behavior changed.
5. **`package-lock.yml`** — only relevant if external package dependencies change (currently always `packages: []`); not affected by version bumps of this package itself.

## Checklist before finishing any behavioral change

- [ ] Code change implemented, following existing patterns in the same macro directory
- [ ] `dbt-verify` (or manual Jinja/SQL review + `dbt parse`) run and passing
- [ ] `CHANGELOG.md` new version section added
- [ ] `dbt_project.yml` version bumped
- [ ] `README.md` version bumped in both places
- [ ] `README.md` macro reference table / `macros/**/*.yml` docs updated if signatures changed
- [ ] Working on a feature/fix branch, not `main`
- [ ] New/changed Jinja checked against the dbt Fusion (dbt 2.0) pitfalls below

## dbt Fusion (dbt 2.0) compatibility

This package must work on **both** dbt-core (`>=1.9.4`) and dbt Fusion (dbt 2.0, `require-dbt-version: [">=1.9.4", "<3.0.0"]`). Fusion is stricter than dbt-core's Jinja/Python resolution in several ways that have caused real bugs here — check new/changed macros against all of these:

1. **No dotted-path `selectattr`.** `nodes | selectattr("config.materialized", "equalto", "task")` only "worked" on dbt-core by accident of Python attribute resolution and fails to filter correctly elsewhere. Always use an explicit loop with `node.config.get("materialized")` instead.
2. **No internal `default__`-prefixed macro calls.** Call the public, adapter-dispatched macro (e.g. `get_merge_sql()`), never `default__get_merge_sql()` directly — internal macro resolution isn't guaranteed under Fusion's dispatch.
3. **No legacy 2-positional-arg `ref()`.** `ref('package_name', 'model_name')` is removed under Fusion. Use the keyword form `ref('model_name', package='package_name')`. The package's own `ref()` override macro (`macros/schema/ref.sql`) must forward `package`/`version` kwargs correctly and keep `include_database` in its original positional slot for backward compatibility.
4. **Avoid Agate-specific positional access on `run_query()` results.** Don't use `result.values()[N]` or `result.columns[N].values()`. Use named-column dict access (`result['COLUMN_NAME']`) or, when iterating rows from a `->> select ...` pipe query, consistent positional row/column indexing (`row[0]`) as already used in `get_grant_task_ownership_sql.sql`-style macros — never hardcode a column's *position* in `SHOW <OBJECT>S` output (locate by name).
5. **Mind Snowflake's casing behavior** (identical on both engines, but easy to get wrong): unquoted `SELECT ... AS alias` results come back **uppercase**; `SHOW <OBJECT>` command output columns (e.g. `"name"`, `"schema_name"`, `"state"`) come back **lowercase**, and `ilike`/case-insensitive matching should be used when comparing a lowercase dbt graph node name (`node.name`) against Snowflake's stored (often uppercase) object name.
6. **Verify on both engines when feasible** — run `dbt parse` / `dbt compile` (and ideally the affected macro live) against `integration_tests/` on both dbt-core and dbt Fusion. CI runs an `dbt-fusion` matrix leg in `.github/workflows/integration_tests.yml`.
7. **`flags.WHICH` values are confirmed identical** across dbt-core and Fusion (`run-operation`, `compile`, `test`, `run`, `build`), so existing `flags.WHICH` guards don't need per-engine special-casing.

