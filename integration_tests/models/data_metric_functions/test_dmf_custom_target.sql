-- Fixture model that attaches the custom DMF (test_custom_dmf) via apply_data_metric_functions'
-- model-level `meta.dmf_custom` support -- a direct regression test for custom DMF attachment
-- (ref() resolution, DAG ordering, and the ALTER ... ADD DATA METRIC FUNCTION <custom> syntax).
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
