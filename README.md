This [dbt](https://github.com/dbt-labs/dbt) package contains macros that can be (re)used across dbt projects.

> require-dbt-version: [">=1.8.0", "<2.0.0"]
----

## Installation Instructions
Add the following to your packages.yml file
```
  - git: https://github.com/DataEngineersNZ/dbt-snowflake-datops-utils.git
    revision: "0.3.8.2"
```
----

## Contents

Below is a catalogue of publicly supported macros grouped by domain. Internal helpers (those with docs.show: false or purely supportive behavior) are intentionally excluded. Where helpful, a short description is inlined; consult the YAML files for full argument metadata.

**checks**

- `get_populated_array` – first non-empty array from two candidates
- `get_populated_array_value_as_string` – join first non-empty array
- `get_populated_array_value_or_string_as_string` – array joined or fallback string
- `get_populated_numeric_value` – first numeric else 0
- `get_populated_string_value` – first string else ''

**clean**

- `clean_functions` – drop orphaned UDFs
- `clean_generic` – drop orphaned streams/tasks/stages
- `clean_models` – drop orphaned tables/views/external tables
- `clean_objects` – orchestrate all clean macros
- `clean_schemas` – drop schemas not in project
- `clean_stale_models` – drop models older than N days

**database**

- `database_clone` – zero-copy clone a database
- `database_destroy` – drop database
- `schema_clone` – zero-copy clone a schema

**dependancies** (non-lineage referencing)

- `depends_on_ref` – commented reference to model
- `depends_on_source` – commented reference to source

**dynamic_tables**

- `target_lag_environment` – lag by environment
- `target_warehouse_environment` – warehouse by environment

**grants** (see refactored patterns section below)

- `grant_database_ownership`
- `grant_integration_ownership`
- `grant_database_usage`
- `grant_integration_usage`
- `grant_object`
- `grant_privileges`
- `grant_schema_monitor`
- `grant_schema_monitor_specific`
- `grant_schema_operate`
- `grant_schema_operate_specific`
- `grant_schema_ownership`
- `grant_schema_procedure_usage`
- `grant_schema_procedure_usage_specific`
- `grant_schema_read`
- `grant_schema_read_specific`
- `grant_share_read`
- `grant_share_read_specific_schema`
- `grant_usage_to_application`
- `grants_smoke_test` – CI/dry-run validation harness

**merge**

- `get_merge_statement`
- `get_default_merge_statement`

**modelling**

- `date_key`
- `datetime_from_dim`
- `datetime_to_date_dim`
- `datetime_to_time_dim`
- `dimension_id`
- `generate_surrogate_key`
- `time_key`
- `unknown_member`

**parse**

- `first_day_of_month`
- `last_day_of_month`
- `null_to_empty_string`
- `num_to_date`
- `string_to_num`
- `to_date`
- `string_epoch_to_timestamp_ltz`
- `string_epoch_to_timestamp_ntz`

**pre-hooks**

- `drop_view_if_exists`
- `drop_table_if_exists`
- `drop_views_in_schema_for_snapshots`

**schema**

- `generate_schema_name` (override)
- `model_ref`
- `model_source`
- `ref` (enhanced include_database)
- `source` (enhanced include_database)

**tags**

- `apply_meta_as_tags`

**tasks**

- `enable_dependent_tasks`
- `execute_task`

### Grants Management (Refactored Patterns)

Recent refactors introduced a consistent pattern across grant-related macros for clarity, auditability, and safety:

Key characteristics:
- Early exit guards: macros skip execution outside `run` / `run-operation` contexts.
- Logging only for top-level macros: operational macros write human-readable summaries instead of returning data structures.
- Statement batching with consistent formatting and explicit counts (revokes vs grants).
- Ownership helper macros still return statement lists internally (consumed by `grant_schema_ownership`).
- Optional dry-run mode to preview changes.

Dry-run mode:
Set a project or CLI var `grants_dry_run: true` to log all statements without executing them for the following macros:
`grant_schema_monitor`, `grant_schema_operate`, `grant_share_read`, `grant_share_read_specific_schema`, `grant_privileges`.

Example CLI usage:
```
dbt run-operation grant_schema_operate --args '{"exclude_schemas": [], "grant_roles": ["OPS_SUPPORT"]}' --vars '{"grants_dry_run": true}'
```

Example project-level configuration (`dbt_project.yml`):
```yaml
vars:
  grants_dry_run: true  # disable to allow execution
```

Sample log output pattern:
```
grant_schema_operate: processing 5 schemas for roles: OPS_SUPPORT
revoke operate on TASK in schema MY_DB.MY_SCHEMA.MY_TASK from role OLD_ROLE;
grant operate on all tasks in schema MY_DB.MY_SCHEMA to role ops_support;
grant_schema_operate_specific summary: 1 revokes, 2 grants (dry_run=True)
```

Recommended workflow:
1. Run with `grants_dry_run: true` and review logs in CI.
2. Approve changes, re-run with dry-run disabled to apply.

High-level macro intent summary:
- `grant_schema_read*`: Ensures read usage, SELECT/REFERENCE privileges, optional future grants.
- `grant_schema_monitor*`: Grants MONITOR on tasks/pipes + schema usage.
- `grant_schema_operate*`: Grants OPERATE on tasks/pipes + schema usage.
- `grant_schema_procedure_usage*`: Grants USAGE on all procedures + schema usage, with future grants.
- `grant_share_read*`: Manages secure view exposure to outbound shares (revokes unmanaged, grants managed).
- `grant_object`: Reconciles privilege sets on specific objects (TABLE/VIEW/PROCEDURE/FUNCTION/etc).
- `grant_privileges`: Environment-aware bundle orchestrator.

Notes:
- Privilege diffing avoids redundant grants.
- Revokes are only issued for privileges outside desired scope (or for unmanaged grantees when revocation is enabled).
- Ownership grants always use `revoke current grants` to move ownership cleanly.

Future enhancement ideas (not yet implemented):
- Generic unified privilege macro parameterized by privilege type.
- Aggregated dry-run report macro producing a JSON artifact.
- Caching of SHOW results across macros within a single run-operation invocation.

Contributions welcome. Keep macro signatures stable to avoid breaking downstream usage.

---

### Tagging macros

#### dbt_dataengineers_utils.apply_meta_as_tags

This macro applies specific model meta properties as Snowflake tags during `post-hook`. This allows you to apply Snowflake tags as part of your dbt project. Tags should be defined outside dbt and stored in a separate database.
When dbt re-runs and re-creates the views the tags will be re-applied as they will disappear from the deployed view.

##### Permissions

The users role running the macro must have the `apply tag` permissions on the account. For example if you have a `developers` role:
```sql
grant apply tag on account to role developers;
```

##### Arguments

- tag_names(required): A list of tag names to apply to the model if they exist as part of the metadata. These should be defined in your Snowflake account.

##### Usage

```yaml
models:
  - name: your_view_name
    columns:
      - name: surname
        description: surname
        type: VARCHAR
        data_type: VARCHAR
        meta:
          pii_type: name
```

The macro must be called as part of post-hook, so add the following to dbt_project.yml:

```yaml
post-hook:
    - "{{ dbt_dataengineers_utils.apply_meta_as_tags(['pii_type']) }}"
```

The variables must be defined in your dbt_project.yml:

```yaml
  #########################################
  ### dbt_dataengineers_utils variables ###
  #########################################
  #The database name where tags and masking policies live
  data_governance_database: "DATA_GOVERNANCE"
  #The schema name where tags are located
  tag_store: "TAG_STORE"
```

##### Tags
Define your meta data with `_type` at the end and it will apply the tag with the same name but replace `_type` with `_data`.
