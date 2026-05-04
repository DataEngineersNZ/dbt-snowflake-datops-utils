-- Assert: last_day_of_month returns non-leap year date
select * from {{ ref('test_parse') }}
where last_day_non_leap != '2023-02-28'::date
