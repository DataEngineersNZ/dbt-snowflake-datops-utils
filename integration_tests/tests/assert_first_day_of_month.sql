-- Assert: first_day_of_month returns correct date
select * from {{ ref('test_parse') }}
where first_day_result != '2024-03-01'::date
