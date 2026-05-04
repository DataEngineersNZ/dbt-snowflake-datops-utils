-- Assert: get_populated_string_value returns populated value
select * from {{ ref('test_checks') }}
where string_value_populated != 'hello'
