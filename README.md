This [dbt](https://github.com/dbt-labs/dbt) package contains macros that can be (re)used across dbt projects.

> require-dbt-version: [">=1.3.0", "<2.0.0"]
----

## Installation Instructions
Add the following to your packages.yml file
```
  - git: https://github.com/DataEngineersNZ/dbt-snowflake-datops-utils.git
    revision: "0.2.0"
```
----

## Contents

**atomic-unit-tests**

- unit_test

**clean**

- clean_functions
- clean_generic
- clean_models
- clean_objects
- clean_schemas
- clean_stale_models
- drop_object

**dependancies**

- depends_on_ref
- depends_on_source

**grants**
 
 - grant_database_ownership_access
 - grant_database_usage_access
 - grant_privileges
 - grant_schema_ownership_access
 - grant_schema_read_access
 - grant_schema_write_access

 **helpers**

 - get_merge_statement

 **modelling**

 - date_key
 - datetime_from_dim
 - datetime_to_date_dim
 - datetime_to_time_dim
 - dimension_id
 - time_key

 **parse**

 - first_day_of_month
 - last_day_of_month
 - to_date

**schema**

 - generate_schema_name
 - model_ref
 - model_source
 - ref
 - source
