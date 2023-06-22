# Data Engineers Snowflake DataOps Utils Project Changelog

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
