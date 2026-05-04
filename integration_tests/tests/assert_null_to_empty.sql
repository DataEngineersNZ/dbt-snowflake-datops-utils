-- Assert: null_to_empty_string returns '' for NULL
select * from {{ ref('test_parse') }}
where null_to_empty_result != ''
