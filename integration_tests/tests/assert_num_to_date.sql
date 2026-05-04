-- Assert: num_to_date converts correctly
select * from {{ ref('test_parse') }}
where num_to_date_result != '2024-03-15'::date
