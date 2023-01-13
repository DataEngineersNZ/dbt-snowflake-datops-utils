# Data Engineers Snowflake DataOps Utils Project Changelog

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
