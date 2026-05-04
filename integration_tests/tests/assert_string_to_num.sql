-- Assert: string_to_num converts comma-formatted string
select * from {{ ref('test_parse') }}
where string_to_num_result != 1234567
