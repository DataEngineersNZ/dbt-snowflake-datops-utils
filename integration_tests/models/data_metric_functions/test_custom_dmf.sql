-- Fixture custom DMF for apply_data_metric_functions integration tests: counts rows where
-- arg_c1 is negative. Authored via dbt_dataengineers_materializations' data_metric_function
-- materialization (the companion package this macro attaches custom DMFs created by).
{{ config(
    materialized='data_metric_function',
    meta={
        'table_arguments': 'arg_t TABLE(arg_c1 NUMBER)',
        'is_secure': false
    }
) }}

SELECT COUNT(*) FROM arg_t WHERE arg_c1 < 0
