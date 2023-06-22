This [dbt](https://github.com/dbt-labs/dbt) package contains macros that can be (re)used across dbt projects.

> require-dbt-version: [">=1.3.0", "<2.0.0"]
----

## Installation Instructions
Add the following to your packages.yml file
```
  - git: https://github.com/DataEngineersNZ/dbt-snowflake-datops-utils.git
    revision: "0.2.4.2"
```
----

## Contents

**Atomic Unit Tests**

- unit_test
- get_value_or_null

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
 - num_to_date
 - string_to_num
 - null_to_empty_string

**schema**

 - generate_schema_name
 - model_ref
 - model_source
 - ref
 - source

---

### Atomic Unit Tests

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


