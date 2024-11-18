This [dbt](https://github.com/dbt-labs/dbt) package contains macros that can be (re)used across dbt projects.

> require-dbt-version: [">=1.6.0", "<2.0.0"]
----

## Installation Instructions
Add the following to your packages.yml file
```
  - git: https://github.com/DataEngineersNZ/dbt-snowflake-datops-utils.git
    revision: "0.3.5"
```
----

## Contents


**Checks**

- `get_populated_array`
- `get_populated_array_value_as_string`
- `get_populated_array_value_as_number`
- `get_populated_numeric_value`
- `get_populated_string_value`

**clean**

- `clean_functions`
- `clean_generic`
- `clean_models`
- `clean_objects`
- `clean_schemas`
- `clean_stale_models`
- `drop_object`

**database**

- `database_clone`
- `database_desctroy`
- `schema_clone`

**dependancies**

- `depends_on_ref`
- `depends_on_source`

**dynamic_tables**

- `target_lag_environment`
- `target_warehouse_environment`

**grants**

- `grant_database_ownership`
- `grant_integration_ownership`
- `grant_database_usage`
- `grant_integration_usage`
- `grant_object`
- `grant_privileges`
- `grant_schema_monitor`
- `grant_schema_operate`
- `grant_schema_onwership`
- `grant_schema_read`
- `grant_share_read`

**helpers**

- `enable_dependent_tasks`
- `get_merge_statement`

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

- `generate_schema_name`
- `model_ref`
- `model_source`
- `ref`
- `source`

**tags**

- `apply_meta_as_tags`
- `model_columns_contains_tag_meta`
- `set_column_tag_value`

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
