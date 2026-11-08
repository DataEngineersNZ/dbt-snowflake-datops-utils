-- Fixture model that attaches the custom DMF (test_custom_dmf) via apply_data_metric_functions'
-- model-level `meta.dmf_custom` support -- a direct regression test for custom DMF attachment
-- (ref() resolution, DAG ordering, and the ALTER ... ADD DATA METRIC FUNCTION <custom> syntax).
select 1 as dmf_custom_test_id, 5 as dmf_custom_test_value
union all
select 2 as dmf_custom_test_id, -3 as dmf_custom_test_value
