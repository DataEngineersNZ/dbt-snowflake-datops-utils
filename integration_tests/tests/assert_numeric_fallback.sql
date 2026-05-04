-- Assert: get_populated_numeric_value falls back when 0
select * from {{ ref('test_checks') }}
where numeric_value_fallback != 42
