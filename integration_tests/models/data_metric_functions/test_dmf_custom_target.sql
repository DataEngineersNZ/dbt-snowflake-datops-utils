-- depends_on: {{ ref('test_custom_dmf') }}
-- Fixture model that attaches the custom DMF (test_custom_dmf) via apply_data_metric_functions'
-- model-level `meta.dmf_custom` support -- a direct regression test for custom DMF attachment
-- (ref() resolution, DAG ordering, and the ALTER ... ADD DATA METRIC FUNCTION <custom> syntax).
--
-- The `depends_on` hint above is required on dbt-core (not dbt-fusion): dbt-core's static
-- dependency inference only scans the model's own .sql file text for literal ref() calls --
-- it can't trace a ref() that lives inside a macro invoked indirectly via post_hook. Without
-- this hint, dbt-core raises "dbt was unable to infer all dependencies" at compile time.
-- Any consuming project using meta.dmf_custom on dbt-core needs this same hint.
--
-- post-hook/meta are set here (not in the schema YAML's model-level `config:` block) --
-- see test_dmf_source.sql for why.
{{ config(
    materialized='view',
    post_hook=["{{ dbt_dataengineers_utils.apply_data_metric_functions() }}"],
    meta={
        "dmf_schedule": "30 MINUTE",
        "dmf_custom": [
            {
                "ref": "test_custom_dmf",
                "columns": ["dmf_custom_test_value"],
                "expectation_name": "dmf_custom_target_no_negative_values",
                "expectation_value": 0
            }
        ]
    }
) }}

select 1 as dmf_custom_test_id, 5 as dmf_custom_test_value
union all
select 2 as dmf_custom_test_id, -3 as dmf_custom_test_value
