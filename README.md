# dbt_dataengineers_utils

A macro-only [dbt](https://github.com/dbt-labs/dbt) package for Snowflake DataOps. Provides utilities for object lifecycle management, RBAC grant orchestration, dimensional modelling helpers, tagging, shares, and more.

- **Version**: 1.5.1
- **dbt**: `>=1.9.4, <3.0.0`
- **Dependencies**: None (zero external package dependencies)
- **dbt Fusion**: Compatible

---

## Installation

Add the following to your `packages.yml`:

```yaml
packages:
  - git: https://github.com/DataEngineersNZ/dbt-snowflake-datops-utils.git
    revision: "1.5.1"
```

Then run `dbt deps`.

---

## dbt Fusion Compatibility

All macros in this package are compatible with dbt Fusion. The package uses only standard dbt-core Jinja APIs (`flags.WHICH`, `run_query()`, `adapter.get_relation()`, `dbt.concat()`, `dbt.type_string()`, `graph.nodes`). No third-party packages are required.

---

## Project Variables

The following `vars` can be set in your `dbt_project.yml` or via `--vars` on the CLI:

| Variable | Default | Used By | Description |
|---|---|---|---|
| `data_governance_database` | `"DATA_GOVERNANCE"` | `apply_meta_as_tags` | Database where tags and masking policies are stored |
| `tag_store` | `"TAG_STORE"` | `apply_meta_as_tags` | Schema where tags are located |
| `unknown_member_surrogate_key` | *(required)* | `unknown_member` | Surrogate key value for the unknown member row |
| `surrogate_key_treat_nulls_as_empty_strings` | `false` | `generate_surrogate_key` | When true, NULLs become `''` instead of a sentinel string |
| `grants_dry_run` | `false` | Grant macros | When true, log all grant/revoke statements without executing |
| `dmf_schedule` | `"60 MINUTE"` | `apply_data_metric_functions` | Project-wide DATA_METRIC_SCHEDULE; overridden per-model by `config.meta.dmf_schedule` |

---

## Macro Reference

### checks

| Macro | Description |
|---|---|
| `get_populated_array(col_to_check, col_to_fall_back_on)` | Return the first non-empty array among two candidates |
| `get_populated_array_value_as_string(col_to_check, col_to_fall_back_on)` | Join the first non-empty array into a delimited string |
| `get_populated_array_value_or_string_as_string(col_to_check, col_to_fall_back_on)` | Return array contents as string if present, else fall back to provided string |
| `get_populated_numeric_value(col_to_check, col_to_fall_back_on)` | Return first non-null numeric value, else 0 |
| `get_populated_string_value(col_to_check, col_to_fall_back_on)` | Return first non-empty string value, else empty string |

### clean

| Macro | Description |
|---|---|
| `clean_objects(database, clean_targets, object_types, current_project_only)` | Orchestrate all clean macros for specified object types and environments |
| `clean_schemas(database, dry_run, current_project_only)` | Drop schemas not defined in the dbt project |
| `clean_models(database, dry_run, current_project_only)` | Drop orphaned tables/views/dynamic tables/external tables/materialized views |
| `clean_functions(database, dry_run, current_project_only)` | Drop orphaned UDFs and stored procedures (excludes DMFs) |
| `clean_data_metric_functions(database, dry_run, current_project_only)` | Drop orphaned Data Metric Functions (DMFs) |
| `clean_generic(object_type, database, dry_run, current_project_only)` | Drop orphaned tasks/streams/stages/alerts/file formats/network rules/secrets/semantic views/agents |
| `clean_stale_models(database, schema, days, dry_run)` | Drop models older than N days from a specific schema |

### data_metric_functions

| Macro | Description |
|---|---|
| `apply_data_metric_functions()` | Post-hook: attach system DMFs (`dmf_not_null`, `dmf_unique`, `dmf_accepted_values` per-column `meta`) and/or custom DMFs (model-level `meta.dmf_custom`, for DMFs authored via `dbt_dataengineers_materializations`' `data_metric_function` materialization) to the current model. Also sets `DATA_METRIC_SCHEDULE` (model `meta.dmf_schedule` > `dmf_schedule` var > `60 MINUTE`). |

### database

| Macro | Description |
|---|---|
| `database_clone(source_database, destination_database, new_owner_role, comment, include_internal_stages)` | Zero-copy clone a database with optional ownership transfer and internal stage cloning |
| `database_clone_grant_ownership(destination_database, new_owner_role)` | Grant ownership of a cloned database and all its schemas, tables, and views to a role |
| `database_destroy(database_name)` | Drop the supplied database |
| `schema_clone(source_schema, destination_schema, source_database, destination_database, new_owner_role)` | Zero-copy clone a schema with optional ownership transfer |

### dependencies

| Macro | Description |
|---|---|
| `depends_on_ref(include_for, model)` | Add a commented reference to a model for implicit lineage. `include_for`: `docs`, `run`, or `all` |
| `depends_on_source(include_for, schema, model, include_database)` | Add a commented reference to a source for implicit lineage |

### dynamic_tables

| Macro | Description |
|---|---|
| `target_lag_environment(duration_prod, duration_test, duration_other)` | Return lag duration based on the current target environment |
| `target_warehouse_environment()` | Return warehouse name based on the current target environment (DEV_WH for local-dev, DATAOPS_WH otherwise) |

### grants

| Macro | Description |
|---|---|
| `grant_database_ownership(role_name)` | Grant ownership on the target database to a role |
| `grant_database_usage(grant_roles, grant_shares, revoke_current_grants)` | Grant/revoke USAGE on the target database to roles and shares |
| `grant_integration_ownership(integration_name, role_name)` | Grant ownership on an integration to a role |
| `grant_integration_usage(integration_name, role_name)` | Grant USAGE on an integration to a role |
| `grant_schema_ownership(exclude_schemas, role_name)` | Grant ownership on all schema objects to a role |
| `grant_schema_read(exclude_schemas, grant_roles, include_future_grants)` | Grant USAGE + SELECT across all schemas to roles |
| `grant_schema_read_specific(schemas, grant_roles, include_future_grants, revoke_current_grants)` | Grant USAGE + SELECT on specific schemas to roles |
| `grant_schema_monitor(exclude_schemas, grant_roles)` | Grant MONITOR on tasks/pipes across all schemas |
| `grant_schema_monitor_specific(schemas, grant_roles, revoke_current_grants)` | Grant MONITOR on tasks/pipes in specific schemas |
| `grant_schema_operate(exclude_schemas, grant_roles)` | Grant OPERATE on tasks/pipes across all schemas |
| `grant_schema_operate_specific(schemas, grant_roles, revoke_current_grants)` | Grant OPERATE on tasks/pipes in specific schemas |
| `grant_schema_procedure_usage(exclude_schemas, grant_roles)` | Grant USAGE on all procedures across all schemas |
| `grant_schema_procedure_usage_specific(schemas, grant_roles, revoke_current_grants, dry_run)` | Grant USAGE on all procedures in specific schemas |
| `grant_schema_object_privileges(object_type, schema_name, permissions, roles)` | Bulk grant privileges on all objects of a type within a schema |
| `grant_object(object_type, objects, grant_types, grant_roles)` | Grant privileges on specific objects to roles (grant-only, no revokes) |
| `grant_object_application(object_type, objects, grant_types, grant_applications)` | Reconcile privilege sets on specific objects for applications |
| `grant_usage_to_application(object_type, prefix, grant_applications)` | Grant USAGE on objects matching a prefix to applications |
| `grant_operate_to_application(prefix, grant_applications)` | Grant OPERATE on tasks matching a prefix to applications |
| `grant_share_read(view_names, grant_shares, revoke_current_grants)` | Manage secure view exposure to outbound shares |
| `grant_share_read_specific_schema(schema_name, view_names, grant_shares, revoke_current_grants)` | Grant SELECT on views in a specific schema to shares |
| `grant_internal_share_read(share_name, exclude_schemas, dry_run)` | Grant SELECT on all tables/views to an internal share |
| `grant_external_share_read(share_name, include_schemas, dry_run)` | Grant SELECT on all tables/views in specified schemas to an external share |
| `grant_agent_usage(schema_name, grant_roles, revoke_roles)` | Grant/revoke USAGE on AGENT views in a schema |
| `grant_semantic_views_privileges(exclude_schemas, grant_roles, include_future_grants)` | Grant SELECT on semantic views across all schemas |
| `grant_privileges(domain_schemas)` | Environment-aware orchestrator that calls multiple grant macros |
| `grants_smoke_test(role, sample_schema)` | CI/dry-run validation harness for grant macros |
| `create_database_role(database_role_names, comment)` | Create one or more database roles (idempotent via `IF NOT EXISTS`) |
| `grant_database_role_schema_privileges(permissions, schema_names, database_roles)` | Grant schema-level privileges (e.g. USAGE) to one or more database roles |
| `grant_database_role_object_privileges(object_type, schema_names, permissions, database_roles)` | Bulk grant privileges on all objects of a type within a schema to database roles |
| `grant_database_role_object(object_type, objects, grant_types, database_roles)` | Grant privileges on specific objects to database roles (grant-only, no revokes) |
| `revoke_database_role_object(object_type, objects, grant_types, database_roles)` | Revoke privileges on specific objects from database roles |
| `grant_database_role_to_role(database_role_name, role_names)` | Grant a database role to one or more account roles |
| `grant_database_role_to_application(database_role_name, application_names)` | Grant a database role to one or more Snowflake Native Apps |
| `grant_database_role_inherited_privileges(object_type, permissions, database_roles, include_schemas, exclude_schemas)` | Grant INHERITED privileges (auto-covers current and future objects) at schema or database level to database roles |
| `revoke_database_role_inherited_privileges(object_type, permissions, database_roles, include_schemas, exclude_schemas)` | Revoke INHERITED privileges at schema or database level from database roles |
| `grant_database_role_object_by_prefix(object_type, prefix, grant_types, database_roles, include_schemas, exclude_schemas)` | Grant privileges to database roles on all objects of a type whose name starts with a prefix |
| `apply_database_roles(database_roles)` | Declarative orchestrator: create + explicit revoke + grant + role/application mapping for a dict of database roles |

### merge

| Macro | Description |
|---|---|
| `get_merge_statement(source, destination_table, destination_schema, unique_key, predicates)` | Generate a MERGE statement using adapter methods |
| `get_default_merge_statement(source, destination_table, destination_schema, unique_key, predicates)` | Generate a MERGE statement using the default adapter implementation |

### modelling

| Macro | Description |
|---|---|
| `date_key(DateKey)` | Convert a date column to `YYYYMMDD` format string |
| `time_key(TimeKey)` | Convert a time column to `HHMI` format string |
| `datetime_from_dim(dateKey, timeKey, dt_format)` | Reconstruct a timestamp from date/time dimension keys |
| `datetime_to_date_dim(col)` | Extract a `YYYYMMDD` date key from a datetime column |
| `datetime_to_time_dim(col)` | Extract a `HHMI` time key from a datetime column |
| `dimension_id(field_list)` | Concatenate fields into a surrogate identifier for a dimension PK |
| `generate_surrogate_key(field_list)` | MD5 hash of concatenated fields, with configurable NULL handling |
| `unknown_member(model_name)` | Generate an "unknown member" row for a dimension table based on column metadata in the dbt graph |

### parse

| Macro | Description |
|---|---|
| `first_day_of_month(s_year, s_month, month_format)` | Generate a date for the first day of the month |
| `last_day_of_month(s_year, s_month, month_format)` | Generate a date for the last day of the month |
| `to_date(s_date, date_format)` | Parse a string into a date using the supplied format |
| `num_to_date(date_field)` | Convert a numeric `yyyymmdd` value to a date |
| `string_to_num(field)` | Convert a numeric-looking string to a number |
| `null_to_empty_string(field)` | Replace NULL with empty string |
| `string_epoch_to_timestamp_ltz(given_date)` | Convert a `/Date(...)` epoch string to TIMESTAMP_LTZ |
| `string_epoch_to_timestamp_ntz(given_date)` | Convert a `/Date(...)` epoch string to TIMESTAMP_NTZ |

### pre-hooks

| Macro | Description |
|---|---|
| `drop_view_if_exists()` | Drop the existing view before creating a dynamic table (pre-hook) |
| `drop_table_if_exists()` | Drop the existing table before creating a dynamic table (pre-hook) |
| `drop_views_in_schema_for_snapshots(schema_name, dry_run, database)` | Drop views in a schema that match snapshot nodes (pre-hook for snapshots) |

### schema

| Macro | Description |
|---|---|
| `generate_schema_name(custom_schema_name, node)` | Override: derives schema name from folder structure |
| `ref(model_name, include_database, package, version)` | Enhanced ref with optional `include_database` parameter for cross-database references. For cross-package refs, use `ref('model_name', package='package_name')` -- the legacy `ref('package_name', 'model_name')` two-positional-argument form is not supported under dbt Fusion (dbt 2.0) |
| `source(schema_name, model_name, include_database)` | Enhanced source with optional `include_database` parameter |
| `model_ref(model_name)` | Return a model relation without creating a dependency node |
| `model_source(schema_name, model_name, include_database)` | Return a source relation without creating a dependency node |

### shares

| Macro | Description |
|---|---|
| `create_share(share_name, accounts, environments)` | Create/update a Snowflake share and grant usage to accounts |
| `create_internal_share(share_name, reference_databases, environments)` | Create/update a share with unsecured objects and reference usage on additional databases |

### tags

| Macro | Description |
|---|---|
| `apply_meta_as_tags(tag_names)` | Post-hook: apply column meta entries as Snowflake tags |

### tasks

| Macro | Description |
|---|---|
| `enable_dependent_tasks(root_task, enabled_targets)` | Enable all dependent tasks for a root task in allowed environments. Only enables when the root task is currently `SUSPENDED`; skips with a log message if it's already `STARTED` (e.g. a partial run), and raises an error if the task can't be found |
| `execute_task(task_name, enabled_targets)` | Execute a task in allowed environments |

---

## Grants Management

### Patterns

Grant macros follow a consistent pattern:

- **Early exit guards**: macros skip execution outside `run` / `run-operation` contexts
- **Privilege diffing**: avoids redundant grants; only issues changes
- **Revoke safety**: revokes only for privileges outside desired scope
- **Logging**: top-level macros write human-readable summaries
- **Dry-run mode**: set `grants_dry_run: true` to preview all statements

### Dry-Run Mode

Set via CLI or `dbt_project.yml`:

```bash
dbt run-operation grant_schema_operate \
  --args '{"exclude_schemas": [], "grant_roles": ["OPS_SUPPORT"]}' \
  --vars '{"grants_dry_run": true}'
```

```yaml
# dbt_project.yml
vars:
  grants_dry_run: true
```

### Macro Intent Summary

| Macro Pattern | Purpose |
|---|---|
| `grant_schema_read*` | USAGE + SELECT/REFERENCES, optional future grants |
| `grant_schema_monitor*` | MONITOR on tasks/pipes + schema usage |
| `grant_schema_operate*` | OPERATE on tasks/pipes + schema usage |
| `grant_schema_procedure_usage*` | USAGE on all procedures + schema usage |
| `grant_share_read*` | Secure view exposure to outbound shares |
| `grant_object` | Per-object privilege granting for roles (no revokes) |
| `grant_object_application` | Per-object privilege reconciliation for applications |
| `grant_privileges` | Environment-aware bundle orchestrator |

### Recommended Workflow

1. Run with `grants_dry_run: true` and review logs in CI
2. Approve changes, re-run with dry-run disabled to apply

---

## Database Roles

### apply_database_roles

Declarative orchestrator for an entire database role setup. Pass one `database_roles` dict and it creates
every database role, applies explicit revokes, applies inherited (current + future) privilege grants, and
maps each role to the account roles / applications configured for the current target -- replacing a
hand-rolled, multi-step `create_database_role` / `grant_database_role_*` block with a single macro call.

```jinja
{{ dbt_dataengineers_utils.apply_database_roles(database_roles) }}
```

**Payload shape**

`database_roles` is a dict keyed by database role name (string, will be lowercased when used in SQL
identifiers). Each value is a dict with the following keys:

| Key | Type | Required | Description |
|---|---|---|---|
| `comment` | string | No | Passed to `CREATE DATABASE ROLE ... COMMENT = '...'`. Omit for no comment. Only applied on creation -- if the role already exists, its existing comment is left as-is (`create_database_role` uses `CREATE DATABASE ROLE IF NOT EXISTS`, intentionally not `CREATE OR REPLACE`, which Snowflake docs warn drops the role from any shares it's granted to). |
| `inherited` | list of dicts | No (default `[]`) | Current + future privilege grants. Each entry: `{'object_type': '<TYPE>', 'permissions': ['<PRIV>', ...]}`. `object_type` is a singular Snowflake object type (e.g. `TABLE`, `VIEW`, `SCHEMA`, `DYNAMIC TABLE`, `TASK`, `PROCEDURE`), case-insensitive. `permissions` is a list of privilege names (e.g. `['SELECT']`, `['USAGE', 'MONITOR']`). |
| `include_schemas` | list of strings, or omit/`none` | No | Scopes every `inherited` entry to these named schemas. Takes precedence over `exclude_schemas`. Does NOT affect `revoke_inherited` entries -- each one has its own, independent `include_schemas`/`exclude_schemas` (see below). When `object_type` is `SCHEMA`, scoping to named schemas issues a direct schema-level grant instead of `INHERITED` (a schema can't contain other schemas); this applies for every scoping mode, including whole-database. An explicitly empty list (`[]`) means "scope to nothing" (a safe no-op), not "unset" -- it will never fall back to `exclude_schemas` or whole-database scope. |
| `exclude_schemas` | list of strings, or omit/`none` | No | Scopes to every schema in the database *except* these. Ignored if `include_schemas` is set. |
| `roles` | dict of `{target_name: [account_role, ...]}` | No (default `{}`) | Account roles to grant this database role to, per dbt target (e.g. `{'prod': ['ANALYST_ROLE'], 'test': ['ANALYST_ROLE']}`). Only the list for the *current* `target.name` is used; omit a target or use `[]` for "nothing to grant in this target". |
| `applications` | dict of `{target_name: [application_name, ...]}` | No, omit entirely if unused | Snowflake Native Apps to grant this database role to directly (not via an account role), per dbt target. Same per-target lookup behavior as `roles`. |
| `revoke_inherited` | list of dicts | No, omit entirely if unused | Explicit inherited-privilege revokes, run **before** grants. Each entry: `{'object_type': '<TYPE>', 'permissions': ['<PRIV>', ...], 'include_schemas': [...] (optional), 'exclude_schemas': [...] (optional)}`. **Independent of the role's top-level `include_schemas`/`exclude_schemas`** -- omitting both on an entry scopes that revoke to the whole database, not the role's grant scope. This is deliberate: the main use case is cleaning up a role's *previous* (often broader) scope while narrowing it -- see the example below. |
| `revoke_objects` | list of dicts | No, omit entirely if unused | Explicit object-level privilege revokes, run **before** grants. Each entry: `{'object_type': '<TYPE>', 'objects': ['<SCHEMA.OBJECT>', ...], 'grant_types': ['<PRIV>', ...]}`. `objects` entries need the full `SCHEMA.NAME(ARG_TYPE, ...)` signature for `PROCEDURE`/`FUNCTION` (Snowflake allows overloads). **Only removes a *direct* grant** -- see the inherited-grant caveat below. |

**Full example**

```jinja
{% set database_roles = {
  'DB_ROLE_READER': {
    'comment': 'Read access to the DM (marts) schema only - current and future objects',
    'inherited': [
      {'object_type': 'SCHEMA',        'permissions': ['USAGE']},
      {'object_type': 'TABLE',         'permissions': ['SELECT']},
      {'object_type': 'VIEW',          'permissions': ['SELECT']},
      {'object_type': 'DYNAMIC TABLE', 'permissions': ['SELECT']}
    ],
    'include_schemas': ['DM'],
    'roles': {'prod': ['BI_TOOL_ROLE'], 'test': ['BI_TOOL_ROLE']},
    'revoke_inherited': [
      {'object_type': 'SCHEMA',        'permissions': ['USAGE']},
      {'object_type': 'TABLE',         'permissions': ['SELECT']},
      {'object_type': 'VIEW',          'permissions': ['SELECT']},
      {'object_type': 'DYNAMIC TABLE', 'permissions': ['SELECT']}
    ]
  },
  'DB_ROLE_ANALYST': {
    'comment': 'Read access to all schemas/tables/views (current and future)',
    'inherited': [
      {'object_type': 'SCHEMA', 'permissions': ['USAGE']},
      {'object_type': 'TABLE',  'permissions': ['SELECT']},
      {'object_type': 'VIEW',  'permissions': ['SELECT']}
    ],
    'include_schemas': none,
    'roles': {'prod': ['ANALYST_ROLE']}
  },
  'DB_ROLE_PUBLISHER': {
    'comment': 'Usage on stored procedures so data processing can occur',
    'inherited': [
      {'object_type': 'SCHEMA',    'permissions': ['USAGE']},
      {'object_type': 'PROCEDURE', 'permissions': ['USAGE']}
    ],
    'include_schemas': ['DM'],
    'roles': {},
    'applications': {'prod': ['MY_NATIVE_APP']}
  }
} %}

{{ dbt_dataengineers_utils.apply_database_roles(database_roles) }}
```

`DB_ROLE_READER`'s `revoke_inherited` entries omit `include_schemas`/`exclude_schemas`, so they scope to
the **whole database** -- this is the pattern for a role being narrowed in scope (e.g. it used to have
whole-database `TABLE`/`VIEW`/`DYNAMIC TABLE` `SELECT` and schema `USAGE`, now narrowed to `DM` only):
the revoke targets the role's *old*, broader scope, while the `inherited` list above grants the *new*,
narrower one. They're independent entries precisely so the revoke isn't accidentally re-scoped to the
new `include_schemas` (which would leave the stale whole-database grant in place outside `DM`).

**Semantics an API/codegen agent should rely on**

- `revoke_inherited` / `revoke_objects` are **explicit declarations, not drift detection**: this macro never
  inspects a role's current grants and never revokes anything you didn't list. Snowflake has no reliable way
  to pre-check a database role's existing inherited grants on all account versions (no `SHOW INHERITED
  GRANTS`, no `IS_INHERITED` column on `SHOW GRANTS TO DATABASE ROLE` everywhere), so there is no
  reconciliation mode -- omitting a key is a no-op, not an implicit revoke.
- Revokes run before grants for each role (not guaranteed globally across every role in the payload before
  any role's grants -- roles are independent of each other, so this doesn't matter in practice).
- All grant/revoke statements are idempotent and safe to leave in the payload on every run (`GRANT`/`GRANT
  INHERITED` on an already-held grant, and `REVOKE`/`REVOKE INHERITED` on a grant the role doesn't hold, are
  both safe no-ops in Snowflake).
- `roles`/`applications` dicts are keyed by dbt target name (`target.name`, e.g. `prod`, `test`, `dev`) --
  only the entry matching the currently-running target is used; there's no "all targets" wildcard key.
- To grant a database role access to one specific object (not current+future via `inherited`), use
  `grant_database_role_object(object_type, objects, grant_types, database_roles)` directly instead of adding
  it to this payload -- `apply_database_roles` only has grant-side support for `inherited`/`roles`/
  `applications`.
- One-time migration/cleanup revokes for a role being narrowed in scope belong in that role's
  `revoke_inherited` list (see `DB_ROLE_READER` above) rather than a separate hand-written `REVOKE`
  statement -- they're safe to leave in the payload indefinitely.
- **Inherited grants have no object-level exceptions (a genuine Snowflake limitation, not specific to this
  macro).** If a role's `inherited` list already covers an object via a container-level `GRANT INHERITED`
  (e.g. whole-database `TABLE` `SELECT`, as `DB_ROLE_ANALYST` has above), a `revoke_objects` entry for that
  same object and privilege will **not** remove access -- the inherited grant still applies regardless of
  statement order. `revoke_objects` only removes a *direct* (non-inherited) grant, such as one made via
  `grant_database_role_object`. To exclude specific objects from an otherwise-broad role, narrow the
  `inherited` scope itself (e.g. `exclude_schemas`, or per-schema `include_schemas` entries that skip the
  sensitive schema) rather than trying to carve out a per-object exception after the fact.

**Known limitations** (shared with the rest of this package's grant macros, not specific to
`apply_database_roles`):
- No identifier quoting, escaping, or allow-list validation is applied to role/schema/object/privilege
  names before they're interpolated into generated SQL -- consistent with every other `grant_*`/`revoke_*`
  macro in this package. Treat `database_roles` as trusted, project-authored infrastructure-as-code input
  (the same trust level as any other dbt project config), not as a surface for untrusted/external input.
- `exclude_schemas` resolution (via the shared `_grants_collect_schemas` helper, used by several other
  grant macros in this package) compares schema names case-sensitively against Snowflake's returned schema
  names. Match the casing Snowflake actually uses (typically uppercase for unquoted identifiers) when
  listing schemas to exclude.
- Snowflake's `GRANT`/`REVOKE` DDL has no multi-statement transactions, so a `revoke_inherited`/
  `revoke_objects`/grant sequence for a role isn't atomic: if a later statement in the sequence fails (or
  the run is interrupted), earlier statements in that same `apply_database_roles` call are not rolled back.
  This also means two concurrent `apply_database_roles` calls for the *same* role (e.g. parallel CI runs)
  can interleave and leave a mix of both configurations' privileges. Statements are idempotent, so simply
  re-running the same payload converges the role back to the intended state; avoid running
  `apply_database_roles` for the same role from more than one place at a time.

---

## Tagging

### apply_meta_as_tags

Applies column-level meta properties as Snowflake tags during `post-hook`. Tags are defined outside dbt in a governance database.

**Permissions required:**

```sql
grant apply tag on account to role developers;
```

**Model YAML:**

```yaml
models:
  - name: your_view_name
    columns:
      - name: surname
        description: surname
        meta:
          pii_type: name
```

**dbt_project.yml:**

```yaml
post-hook:
  - "{{ dbt_dataengineers_utils.apply_meta_as_tags(['pii_type']) }}"

vars:
  data_governance_database: "DATA_GOVERNANCE"
  tag_store: "TAG_STORE"
```

Meta keys ending with `_type` are mapped to tags with `_classification`. The `default_mask` key is mapped to `default_mask_value`.

---

## Data Metric Functions

### apply_data_metric_functions

Attaches Snowflake Data Metric Functions (DMFs) to a model during `post-hook`, re-applied on every run since `CREATE OR REPLACE TABLE|VIEW` drops any previously attached DMF bindings from scratch. Only `table`, `view`, and `materialized_view` are supported -- see the macro's docstring for why `incremental`/`snapshot` are not.

**Model SQL file** (`stg_orders.sql`) -- set `post-hook` and model-level `meta` here via `config()`, not in the model's schema YAML: a hook string rendered from a model-level YAML `config:` block doesn't reliably resolve package macro namespaces on dbt-core, so the hook silently never attaches anything. If you use `dmf_custom`, also add a `depends_on` hint as the very first line (dbt-core only -- its static dependency inference can't trace a `ref()` call that lives inside a macro invoked via `post_hook`; dbt-fusion doesn't need this):

```sql
-- depends_on: {{ ref('my_custom_order_total_check') }}
{{ config(
    materialized='view',
    post_hook=["{{ dbt_dataengineers_utils.apply_data_metric_functions() }}"],
    meta={
        "dmf_schedule": "30 MINUTE",
        "dmf_custom": [
            {
                "ref": "my_custom_order_total_check",
                "columns": ["order_total", "discount_total"],
                "expectation_name": "order_total_reconciles",
                "expectation_value": 0
            }
        ]
    }
) }}

select ...
```

- `meta.dmf_schedule` is optional -- it overrides the schedule for this model only, falling back to the `dmf_schedule` var, then `'60 MINUTE'`, if omitted.
- `meta.dmf_custom` is optional -- it attaches a custom DMF (authored via the `data_metric_function` materialization in `dbt_dataengineers_materializations`) to this model. Omit it entirely if you only need system DMFs.

**Model YAML** (`stg_orders.yml`) -- column-level DMF flags go under each column's `config.meta`:

```yaml
version: 2

models:
  - name: stg_orders
    description: Staging model for orders.
    columns:
      - name: order_id
        data_type: NUMBER
        description: Unique order identifier.
        config:
          meta:
            dmf_not_null: true   # -> SNOWFLAKE.CORE.NULL_COUNT
            dmf_unique: true     # -> SNOWFLAKE.CORE.DUPLICATE_COUNT (only for genuinely-unique columns)

      - name: order_status
        data_type: TEXT
        description: Order status.
        config:
          meta:
            dmf_accepted_values: ['open', 'shipped', 'closed']   # -> SNOWFLAKE.CORE.ACCEPTED_VALUES

      - name: priority_code
        data_type: NUMBER
        description: Numeric priority code.
        config:
          meta:
            dmf_accepted_values: [1, 2, 3]   # numeric values work too (rendered unquoted)
```

**dbt_project.yml (optional, project-wide schedule default):**

```yaml
vars:
  dmf_schedule: "60 MINUTE"
```

Key points:
- `post-hook` and the model-level `dmf_custom` / `dmf_schedule` meta keys go in the **SQL file's** `config()` call -- not the model's schema YAML.
- The `dmf_not_null` / `dmf_unique` / `dmf_accepted_values` keys go under each **column**'s `config.meta` in the schema YAML.
- Everything is additive -- only set the keys relevant to that column/model; omit `dmf_custom`/`dmf_schedule` entirely to use system DMFs on the default schedule.

---

## Object Lifecycle (clean macros)

The `clean_objects` macro orchestrates removal of Snowflake objects not defined in the dbt project. Use it as a post-hook or via `run-operation`:

```bash
dbt run-operation clean_objects --args '{"clean_targets": ["prod"], "object_types": ["schemas", "tables_and_views", "functions_and_procedures"]}'
```

Supported `object_types`: `schemas`, `functions_and_procedures`, `data_metric_functions`, `tasks`, `streams`, `stages`, `tables_and_views`, `alerts`, `file_formats`, `semantic_views`, `agents`.

All clean macros support `dry_run` mode (default: `true`) to preview drops before executing.

---

## Running Tests

Integration tests live in the `integration_tests/` directory. They exercise all pure SQL expression macros (checks, modelling, parse) with known inputs and assert expected outputs.

**Prerequisites**: A Snowflake connection configured as a dbt profile named `integration_tests`.

```bash
cd integration_tests
dbt deps
dbt build
```

`dbt build` runs the test models (which call each macro with literal values) and then executes singular tests that assert expected output values. All tests passing means the macros produce correct SQL.

A second set of tests are `run-operation` macros (not run by `dbt build`) that assert against live Snowflake
state -- run them after `dbt build` so the fixture models/views they depend on exist:

```bash
dbt run-operation test_has_matching_nodes
dbt run-operation test_grants_helpers
dbt run-operation test_grants_idempotency
dbt run-operation test_clean_macros
dbt run-operation test_database_role_macros
```

**What's tested:**
- **checks**: `get_populated_array`, `get_populated_array_value_as_string`, `get_populated_array_value_or_string_as_string`, `get_populated_numeric_value`, `get_populated_string_value`
- **modelling**: `date_key`, `time_key`, `datetime_from_dim`, `datetime_to_date_dim`, `datetime_to_time_dim`, `dimension_id`, `generate_surrogate_key`
- **parse**: `to_date`, `num_to_date`, `string_to_num`, `null_to_empty_string`, `first_day_of_month`, `last_day_of_month`, `string_epoch_to_timestamp_ltz`, `string_epoch_to_timestamp_ntz`
- **data_metric_functions**: `apply_data_metric_functions` -- live-verified against `INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES`, covering system DMFs (`dmf_not_null`, `dmf_unique`, `dmf_accepted_values` with both string and numeric enum values -- the string case is a regression test for a SQL-quoting bug), a custom DMF attached via model-level `meta.dmf_custom` (requires the `dbt_dataengineers_materializations` package, installed only in `integration_tests/packages.yml`), and the `dmf_schedule` fallback chain (model meta > var > default)
- **database roles** (`test_database_role_macros`, live-verified): `create_database_role`, `grant_database_role_schema_privileges`, `grant_database_role_object` / `revoke_database_role_object` (against an existing view from another test model), `grant_database_role_to_role`, and `apply_database_roles` (create + `inherited`/`revoke_inherited` with `include_schemas` set + `revoke_objects` + `roles` mapping, all in one payload). `GRANT`/`REVOKE INHERITED` itself and `grant_database_role_to_application` are intentionally **not** exercised live: `INHERITED` isn't available on every Snowflake account/edition (confirmed: `Unsupported feature 'INHERITED'` on at least one tested account), and `run_query()` failures can't be caught in Jinja, so hitting that keyword live here would risk breaking CI on accounts without it enabled; granting to an application needs a real installed Native App. Both are covered only by `dbt parse`/`dbt compile`, not live execution.

