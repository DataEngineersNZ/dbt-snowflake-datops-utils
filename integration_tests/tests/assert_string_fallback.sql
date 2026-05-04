-- Assert: get_populated_string_value falls back on empty string
select * from {{ ref('test_checks') }}
where string_value_fallback != 'fallback'
