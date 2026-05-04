-- Assert: date_key produces YYYYMMDD string
select * from {{ ref('test_modelling') }}
where date_key_result != '20240315'
