-- Assert: get_populated_array_value_as_string joins array
select * from {{ ref('test_checks') }}
where array_value_as_string != 'x,y,z'
