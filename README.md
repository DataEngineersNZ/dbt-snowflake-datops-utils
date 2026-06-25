# dbt_dataengineers_utils

A macro-only [dbt](https://github.com/dbt-labs/dbt) package for Snowflake DataOps. Provides utilities for object lifecycle management, RBAC grant orchestration, dimensional modelling helpers, tagging, shares, and more.

- **Version**: 1.0.8
- **dbt**: `>=1.3.0, <3.0.0`
- **Dependencies**: None (zero external package dependencies)
- **dbt Fusion**: Compatible

---

## Installation

Add the following to your `packages.yml`:

```yaml
packages:
  - git: https://github.com/DataEngineersNZ/dbt-snowflake-datops-utils.git
    revision: "1.0.3"
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
| `clean_objects(database, clean_targets, object_types)` | Orchestrate all clean macros for specified object types and environments |
| `clean_schemas(database, dry_run)` | Drop schemas not defined in the dbt project |
| `clean_models(database, dry_run)` | Drop orphaned tables/views/dynamic tables/external tables/materialized views |
| `clean_functions(database, dry_run)` | Drop orphaned UDFs and stored procedures (excludes DMFs) |
| `clean_data_metric_functions(database, dry_run)` | Drop orphaned Data Metric Functions (DMFs) |
| `clean_generic(object_type, database, dry_run)` | Drop orphaned tasks/streams/stages/alerts/file formats/network rules/secrets/semantic views/agents |
| `clean_stale_models(database, schema, days, dry_run)` | Drop models older than N days from a specific schema |

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
| `ref(model_name, include_database)` | Enhanced ref with optional `include_database` parameter for cross-database references |
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
| `enable_dependent_tasks(root_task, enabled_targets)` | Enable all dependent tasks for a root task in allowed environments |
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

**What's tested:**
- **checks**: `get_populated_array`, `get_populated_array_value_as_string`, `get_populated_array_value_or_string_as_string`, `get_populated_numeric_value`, `get_populated_string_value`
- **modelling**: `date_key`, `time_key`, `datetime_from_dim`, `datetime_to_date_dim`, `datetime_to_time_dim`, `dimension_id`, `generate_surrogate_key`
- **parse**: `to_date`, `num_to_date`, `string_to_num`, `null_to_empty_string`, `first_day_of_month`, `last_day_of_month`, `string_epoch_to_timestamp_ltz`, `string_epoch_to_timestamp_ntz`
