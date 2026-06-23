# Data Engineers Snowflake DataOps Utils Project Changelog
This file contains the changelog for the Data Engineers Snowflake DataOps Utils project, detailing updates, fixes, and enhancements made to the project over time.

## v1.0.6 - 2026-06-23 - Database Clone Grant Ownership

### Added
- Added `database_clone_grant_ownership` macro to grant ownership of a cloned database and all its schemas, tables, and views to a specified role. Iterates over all schemas in the destination database (excluding INFORMATION_SCHEMA) and grants ownership on the schema, all tables, and all views to the target role with `COPY CURRENT GRANTS`.

### Changed
- Bumped version from 1.0.5 to 1.0.6

## v1.0.5 - 2026-06-16 - Grant OPERATE on Tasks to Applications

### Added
- Added `grant_operate_to_application` macro to grant OPERATE privilege on tasks matching a name prefix to specified application roles. Discovers tasks via `SHOW TASKS IN DATABASE`, reconciles existing grants (revoking from unlisted applications), and ensures database/schema USAGE is also granted.

### Changed
- Bumped version from 1.0.4 to 1.0.5

## v1.0.4 - 2026-05-21 - Unknown Member Boolean Cast Fix

### Fixed
- Fixed `unknown_member` macro: added explicit `::boolean` casts for `is_current`, `is_deleted`, and generic boolean columns to ensure correct type inference in Snowflake when generating unknown member rows.

### Changed
- Bumped version from 1.0.3 to 1.0.4

## v1.0.3 - 2026-05-16 - Data Metric Function Cleanup Support

### Added
- Added `clean_data_metric_functions` macro to reconcile dbt-defined Data Metric Functions (DMFs) against deployed DMFs in Snowflake and drop orphaned ones. DMFs are identified via `information_schema.functions` where `is_data_metric = 'YES'` and matched against dbt graph nodes with `config.materialized = 'data_metric_function'`.
- Added `data_metric_functions` as a supported `object_type` in the `clean_objects` orchestrator macro (included in the default list).

### Changed
- Modified `clean_functions` macro to exclude Data Metric Functions (`is_data_metric = 'NO'` filter) so DMFs are not incorrectly dropped by the regular function cleanup. DMFs are now handled exclusively by `clean_data_metric_functions`.
- Added `{% if execute %}` guards to all clean macros (`clean_functions`, `clean_generic`, `clean_models`, `clean_schemas`, `clean_stale_models`) to prevent `run_query()` and `graph.nodes` access during parsing or docs generation.
- Bumped version from 1.0.2 to 1.0.3

## v1.0.2 - 2026-05-12 - Clean Functions Signature Fallback Fix

### Fixed
- Fixed `has_matching_nodes` macro: the types-only fallback comparison was only extracting types from the dbt side while comparing against the original Snowflake signature which still contained parameter names. This caused UDFs with DEFAULT parameters (e.g. `target_timezone STRING DEFAULT 'Pacific/Auckland'`) to be incorrectly dropped, because the Snowflake signature `(TARGET_TIMEZONE VARCHAR)` includes parameter names that didn't match the dbt types-only signature `(varchar)`. The fallback now extracts types from both sides before comparing.

### Changed
- Bumped version from 1.0.1 to 1.0.2

## v1.0.1 - 2026-05-10 - Function Signature Matching Fix

### Fixed
- Fixed `has_matching_nodes` macro: Snowflake `information_schema.functions` returns type-only signatures (e.g. `(VARCHAR)`) but dbt parameters include names and DEFAULT clauses (e.g. `target_timezone STRING DEFAULT 'Pacific/Auckland'`). Added type-only fallback comparison that strips parameter names and DEFAULT clauses before matching. This prevents UDTFs/functions with DEFAULT parameters from being incorrectly dropped as orphans.
- Fixed `has_matching_nodes` macro: multi-line parameters (from YAML block scalars or SQL config strings with newlines/tabs) now correctly normalised via `collapse_whitespace` helper -- newlines and tabs are replaced with spaces then iteratively collapsed, handling arbitrarily long runs of whitespace.
- Fixed `has_matching_nodes` and `clean_functions` macros: type extraction now uses `extract_param_type` helper which collects all tokens between the parameter name and `DEFAULT` keyword, correctly handling compound types with parenthesised precision like `NUMBER(15, 2)` or `VARCHAR(100)`.
- Fixed `clean_functions` macro: fallback argument extraction failed on type-only Snowflake signatures because `argument.split(' ')[1]` is out of bounds when the argument is a single type word like `varchar`. Now uses shared helper macros for consistent handling.
- Added `collapse_whitespace`, `split_params`, and `extract_param_type` helper macros in `macros/clean/_helpers.sql` to share whitespace normalisation, parenthesis-aware parameter splitting, and type extraction logic between `has_matching_nodes` and `clean_functions`.

### Changed
- Bumped version from 1.0.0 to 1.0.1

## v1.0.0 - 2026-05-04 - Major Release

### Breaking Changes
- Removed `dbt-labs/dbt_utils` package dependency. This package now has **zero external dependencies** beyond dbt-core. The `generate_surrogate_key` null sentinel value changed from `_dbt_utils_surrogate_key_null_` to `_surrogate_key_null_`. If you rely on exact hash reproducibility with the old sentinel, set `var('surrogate_key_treat_nulls_as_empty_strings', true)` or update downstream comparisons.

### Added
- Macro documentation for `generate_surrogate_key` and `unknown_member` in modelling.yml
- Macro documentation for `grant_external_share_read`, `grant_agent_usage`, `grant_semantic_views_privileges`, and `grant_semantic_views_privileges_specific` in grants.yml
- Macro arguments for `drop_views_in_schema_for_snapshots` in pre-hooks.yml
- Confirmed dbt Fusion compatibility across all macros
- Integration test project (`integration_tests/`) with 3 test models and 22 assertions covering all pure SQL expression macros (checks, modelling, parse)

### Fixed
- Fixed `to_date` macro: extra closing parenthesis caused syntax error (`TO_DATE(col), 'fmt')` -> `TO_DATE(col, 'fmt')`)
- Fixed `first_day_of_month` macro: referenced undefined variables `extract_year`/`extract_month` instead of parameters `s_year`/`s_month`
- Fixed `last_day_of_month` macro: same parameter name bug as `first_day_of_month`
- Fixed `get_populated_string_value` macro: used double-quoted empty string `""` which Snowflake treats as an identifier; changed to single-quoted `''`
- Fixed invalid macro argument types across YAML docs to use dbt-supported types (`ref` -> `string`, `TEXT` -> `string`, `text` -> `string`, `number` -> `string`, `Array` -> `list[string]`, `object` -> `any`/`optional[list[string]]`/`relation`). Resolves all `dbt1506` warnings.
- Fixed `has_matching_nodes` macro: `node.config.parameters` failed to find parameters stored under `node.config.meta.parameters` in dbt graph nodes, causing functions/UDTFs with meta-defined parameters to be incorrectly identified as orphans and dropped. Now falls back through `config.meta.parameters` -> `config.parameters` -> `''`.
- Fixed `has_matching_nodes` macro: `selectattr("config.override_name", ...)` never matched because Jinja2's `selectattr` does not support dotted-path nested attribute lookups. Replaced with manual loop and safe `config.get("meta", {}).get("override_name", ...)` access. This prevents functions using `override_name` from being dropped as orphans.

### Changed
- Bumped version from 0.3.12 to 1.0.0
- Widened `require-dbt-version` to `>=1.3.0, <3.0.0` to support dbt Fusion (2.x)
- Updated README with comprehensive macro reference, variable documentation, and dbt Fusion compatibility notes

## v0.3.12 - 2026-04-30 - Share Reads

- Limiting the macro `grant_share_read` to the current database

## v0.3.11 - 2026-03-24 - External Share Permissions & Internal Stage Cloning

- refactored the _grants_collect_schemas macro to accept schema_names and is_exclude_list parameters, and updated related grant macros for consistency and improved functionality.
- added new macro `grant_external_share_read`  to apply `select` permissions on all tables and views for specified schemas
- modified the macro `database_clone` to optionally allow for the cloning of internal stages

## v0.3.10.6 - 2026-03-19 - Clean up Semantic Views/Agents

* modified macro `clean_objects` to cater for removing Semantic Views and Snowflake Agents

## v0.3.10.5 - 2026-03-10 - Function / Procedure Bulk Grant fix

* modified macro `grant_schema_object_privileges` to to esnure schema is passed correct to the helper macros
* modified macro `get_functions` and `get_procuedures` to ensure the correct handling of arguments

##v0.3.10.4 - 2026-03-09 - Function / Procedure Bulk Grant fix

* modified macro `grant_schema_object_privileges` to correct append arguments to functions and procedures

## v0.3.10.3 - 2026-03-09 - Bulk Grants

* modified macro `grant_schema_object_privileges` to ignore in_built functions and procedures

## v0.3.10.2 - 2026-02-26 - Bulk Grants

* added macro `grant_schema_object_privileges` to be able to apply permissions to all objects within a schema to a role

## v0.3.10.1 - 2026-02-12 - Grant Application Select

* added macro `grant_object_application` to apply the required permissions on the provided object to an application
* updated macro `grant_schema_read` to only process `ROLE` and not `APPLICATION` grant statements

## v0.3.10 - 2026-02-10 - Grant Shares

* added macro `grant_internal_share_read` to apply `select` permissions on all tables and views
* added macro `create_internal_share` which will create a share that allows unsecured objects and grants reference usage on downstream databases
* updated macro `has_matching_nodes` to cater for line breaks in the arguments being passed in
* updated version of `dbt_utils` to 1.3.3

## v0.3.9.1 2025-07-10 - Tag Doc Fix

* fixed issue where tag documentation was not being rendered correctly

## v0.3.9 2025-06-10 - Grant Object For Procedures

* added macro `grant_procedure_usage` to enable the ability to grant usage of a stored procedure to a role

## v0.3.8.5 2025-08-25 - Grant Usage to Application

* added grant usage to application for `sp_sync_` in the `grant_privileges` macro
* fixed issue with `clean_generic` macro not handling `file formats` and `network rules` correctly causing them to be dropped at the end of a dbt run

## v0.3.8.4 2025-08-22 - Materialized View Handling

* added handling for materialized views in the `clean_models` macro

## v0.3.8.3 2025-07-30 - Grant Fixes

* updated macro `get_grant_functions_ownership_sql` to fix issue with parameterless function signature not being returned correctly
* added additional logging to `grant_object` macro to ensure that the correct parameters are being passed

## v0.3.8.2 2025-07-15 - Grant Fixes

* added additional logging to `grant_object` macro to ensure that the correct parameters are being passed

## v0.3.8.1 2025-07-25 - Stored Procedure Grants

* updated macro `get_grant_procedure_ownership_sql` to fix issue with parameterless procedure signature not being returned correctly

## v0.3.8 2025-07-23 - Grant Modifications

* updated `grant_database_ownership` to include the only grant ownership to a role if the role is not already the owner
* updated `grant_schema_ownership` to include the only grant ownership to a role if the role is not already the owner

## v0.3.7 2025-04-30 - Tagging

 * updated macro `apply_meta_as_tags` to enable the ability to apply meta as tags based on definitioins defined within the Monitiorial Data Governance Native App. `_type` is now replaced with `_classification` instead of `_data` and added in mapping of `default_mask` to `default_mask_value`

## v0.3.6 - 2025-04-09 - tasks

 * added macro `execute_task` to enable the ability to execute a task at the end of a run

## v0.3.5.1 - 2025-01-03 - Minor Fixes
 * updated dynamic table model cleaning
 * removed quote from depends_on_ref statement
 * added in run-operation for monitior grants
 * added in dynamic table into read specifics
 * updated depends_on_ref and depends_on_source to cater for dbt-core 1.9 changes
 * get_merge_statement updated to cater for dbt-core 1.9 changes

## v0.3.5 2024-11-18 - Atomic Unit Test Removed

 * removed the macros relating to the atomic unit test as they are no longer required

## v0.3.4 2024-10-31 - Privileges Fixes

 * modified macro `grant_database_ownership` - fixed issue with the macro where ownership was not being granted correctly
 * modified macro `grant_integration_ownership` - fixed issue with the macro where ownership was not being granted correctly
 * modified macro `grant_integration_usgae` - fixed issue with the macro where ownership was not being granted correctly
 * modified macro `grant_schema_ownership` - fixed issue with the macro where usage was not being granted correctly
 * updated `dbt_utils` package to version 1.3.0

## v0.3.3 2024-07-18 - Integration, Network Rules and Secrets

* added macro `grant_integration_ownership` to enable the ability to grant ownership of an integration
* added macro `grant_integration_usage` to enable the ability to grant usage access to an integration
* modified macro `grant_schema_read` to include shares when granting permissions
* modified macro `grant_schema_ownership` to include network rules, secrets and shares when granting permissions
* modified macro `clean_objects` to include network rules and secrets when cleaning objects
* modified macro `clean_generic` to fix schema column positioning for secrets
* modified macros `depends_on_ref` and `depends_on_source` to cater for issues found in dbt-core 1.8
* modified macro `grant_share_read` to only include `OUTBOUND` shares

## v0.3.2 2024-05-15

* modified macros `depends_on_ref` and `depends_on_source` to cater for issues found in dbt-core 1.8

## v0.3.1 2024-03-17

* added macro `create_share` to enable the ability to create a share
* added macro `grant_share_read` to enable the ability to grant a share to an account
* modified `grant_schema_read` to exclude shares when revoking permissions
* modified `grant_database_usage` to take into account shares
* modified `grant_database_usage` to specify to revoke grants or not

## v0.3.0.1 2024-02-15

* Fixed macros `depends_on_ref` and `depends_on_source` to cater for change in dbt behaviour

## v0.3.0 2024-02-15

* Added the ability to grant and revoke access to a role
* Macros added:
    - `grant_database_ownership`
    - `grant_database_usage`
    - `grant_object`
    - `grant_privileges`
    - `grant_schema_monitor`
    - `grant_schema_operate`
    - `grant_schema_onwership`
    - `grant_schema_read`
    - `database_clone`
    - `database_destroy`
    - `schema_clone`

## v0.2.5 2024-01-10

* added macro `enable_dependent_tasks` to enable the ability to enable dependant tasks from a root task
* added query helper macros:
    - `get_populated_array`
    - `get_populated_array_value_as_string`
    - `get_populated_array_value_as_number`
    - `get_populated_numeric_value`
    - `get_populated_string_value`
    - `string_epoch_to_timestamp_ltz`
    - `string_epoch_to_timestamp_ntz`
    - `unknown_member`

## v0.2.4.9 2023-12-20

* corrected naming for `model_contains_tag_meta` macro from `model_columns_contains_tag_meta`
* updated `get_merge_statement` macro to remove the `begin;` and `commit;` statements as they are not required

## v0.2.4.8 2023-12-12

* added macro `apply_meta_as_tags` to enable the ability to apply meta as tags to a table or a view
* added macro `model_columns_contains_tag_meta` to enable the ability to check if a model contains meta data for a column
* added macro `set_column_tag_value` to enable the apply the meta data to a column

## v0.2.4.7 2023-11-01

* added macro `drop_table_if_exists` to enable the ability to drop a table if it exists - designed for dynamic tables.

## v0.2.4.6 2023-10-02

* add macro `drop_view_if_exists` to enable the ability to drop a view if it exists - designed for dynamic tables.

## v0.2.4.5 2023-09-05

* added macro `target_lag_environment` and `target_warehouse_environment` to enable the ability to target a different environment for the lag and warehouse

## v0.2.4.4 2023-08-16

* updated macro `clean_objects` to remove dynamic tables as necessary

## v0.2.4.3 2023-08-11

* updated macro `get_default_merge_statement` and `get_merge_statement` to cater for the case where the source is not a native dbt component (eg stream)
* update `dbt_utils` to use version `1.1.1`

## v0.2.4.2 2023-06-22

* updated macro `clean_objects` to enable a list of environments that should be executed in instead of boolean dry_run flag

## v0.2.4.1 2023-06-08

* updated marco `clean_generic` to cater for monitorial objects
* updated macro `drop_objects` to have message about dry run statements

## v0.2.4 2023-05-18

 * updated macro `get_merge_statement` to allow the destnation schema to be specified
 * added macro `get_default_merge_statement` to allow the use of the merge statement which is non vendor specific

## v0.2.3 2023-04-19

* updated macro `clean_objects` so to enable easier configuration instead of boolean flags
* updated unit test macros to process null's correctly

## v0.2.2 2023-02-10

* updated macro `clean_objects` so that it is able to remove file formats and alerts from snowflake

## v0.2.1 2023-01-31

* added macro `generate_surrogate_key` so that it doesn't include whitespace which appears in the dbt-utils version

## v0.2.0 2023-01-12

* Upgraded project to be compatible with dbt v1.3.2
* Removed reliance on dbt logging which is being depricated
* updated generate_schema_name macro to cater for subfolders in sources for ease of navigating but provides it at the schema level otherwise
* new macros added:
    * dimension_id
    * last_day_of_month
    * first_day_of_month
    * to_date
    * string_to_num
    * num_to_date
    * null_to_empty_string

## v0.1.9 2022-09-09

* Add ability to remove items from a database which are not part of the dbt project

## v0.1.8 2022-08-26

* Added ability to test stored procedures and user defined functions

## v0.1.7 2022-08-18

* Added ability to create external tables

