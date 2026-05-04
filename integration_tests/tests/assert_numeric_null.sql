-- Assert: get_populated_numeric_value falls back when NULL
select * from {{ ref('test_checks') }}
where numeric_value_null != 99
