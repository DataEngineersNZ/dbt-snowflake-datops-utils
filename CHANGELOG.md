# Data Engineers Snowflake DataOps Utils Project Changelog

## v0.3.3 2024-06-14 - Integration, Network Rules and Secrets

* added macro `grant_integration_ownership` to enable the ability to grant ownership of an integration
* added macro `grant_integration_usage` to enable the ability to grant usage access to an integration
* modified macro `grant_schema_read` to include secrets and shares when granting permissions
* modified macro `grant_schema_ownership` to include network rules, secrets and shares when granting permissions
* modified macro `clean_objects` to include network rules and secrets when cleaning objects
* modified macro `clean_generic` to fix schema column positioning for secrets
* modified macros `depends_on_ref` and `depends_on_source` to cater for issues found in dbt-core 1.8

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

