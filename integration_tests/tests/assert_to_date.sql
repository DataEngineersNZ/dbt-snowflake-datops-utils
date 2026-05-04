-- Assert: to_date parses correctly
select * from {{ ref('test_parse') }}
where to_date_result != '2024-03-15'::date
