-- Assert: last_day_of_month returns leap year date
select * from {{ ref('test_parse') }}
where last_day_result != '2024-02-29'::date
