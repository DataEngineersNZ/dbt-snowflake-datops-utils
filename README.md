This [dbt](https://github.com/dbt-labs/dbt) package contains macros that can be (re)used across dbt projects.

> require-dbt-version: [">=1.6.0", "<2.0.0"]
----

## Installation Instructions
Add the following to your packages.yml file
```
  - git: https://github.com/DataEngineersNZ/dbt-snowflake-datops-utils.git
    revision: "0.3.3"
```
----

## Contents

**Atomic Unit Tests**

- `unit_test`
- `get_value_or_null`

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

### Atomic Unit Tests
Since dbt 1.8.0, dbt has introduced the ability to run atomic unit tests.
It is recommended users transition to using the built-in atomic unit tests as they are more efficient and integrated to dbt.
In a future release the atomic unit tests in this package will be depricated.

The following naming conventions are recommended:

| Prefix  | Recommended Name               | Description      | Outputs                           | Macro Output Folder                         | Model Output Folder                   |
| ------- | ------------------------------ | ---------------- | --------------------------------- | ------------------------------------------- | ----------------------------------- |
| `tc__`  | `<<model_name>>_<<test_name>>` | Unit Test Case   | Appended to Test Result or Source |                                             |                                     |
| `utr__` | `<<model_name>>`               | Unit Test Result | macro and sql model               | `macros\unit_tests\outputs\<<schema_name>>` | `models\unit_tests\<<schema_name>>` |
| `uts__` | `<<model_name>>`               | Unit Test Source | macro                             | `macros\unit_tests\inputs\<<schema_name>>`  |                                     |

**Usage for model testing:**
```yaml
models:
  - name: yourModelName
    tests:
      - unit_test:
          name: "tc__yourModelName_yourTestCaseName"
          description: "Your Test Description"
          input_mapping:
            ref('model_to_mock'): "{{ tc__yourModelName_yourTestCaseName_yourMockedModel() }}"
          expected_output: ref('tc__yourModelName_yourTestCaseName__utr__yourExpectedResult')
    columns:
```

If you only want to mock a few columns, you can do so and use the compare_columns field to tell the test which columns to look at, like so:

```yaml
models:
  - name: dim_customer
    description: customer Information
    tests:
      - unit_test:
          name: "tc__yourModelName_yourTestCaseName"
          description: "Your Test Description"
          input_mapping:
            ref('model_to_mock'): "{{ tc__yourModelName_yourTestCaseName_yourMockedModel() }}"
          expected_output: ref('tc__yourModelName_yourTestCaseName__utr__yourExpectedResult')
          compare_columns:
            - column_a
            - column_b
    columns:
```

**Usage for object testing:**
```yaml
models:
  - name: yourStoredProcOrFunctionName
    tests:
      - unit_test:
          test_name: "tc__yourStoredProcOrFunctionName"
          description: "Your Test Description"
          input_mapping:
            ref('model_to_mock'): "{{ tc__yourStoredProcOrFunctionName_has_basic_summary_data__uts__yourMockedModel() }}"
          input_parameters:
            parameter_name: '''parameter_value'''
          expected_output: ref('tc__yourStoredProcOrFunctionName_has_basic_summary_data__utr__yourExpectedResult')
```

If the view has multiple sources then you can add multiple `input_mappings` on separate lines or if you have multiple input parameters you can add multiple `input_parameters` on separate lines.
The `expected_output` has to be a refernece model instead of a macro as a macro is not currently supported.


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
