-- Assert: get_populated_numeric_value returns populated value
select * from {{ ref('test_checks') }}
where numeric_value_populated != 10
