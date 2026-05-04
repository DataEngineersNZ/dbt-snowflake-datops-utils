-- Assert: datetime_to_date_dim produces YYYYMMDD string
select * from {{ ref('test_modelling') }}
where datetime_to_date_result != '20240315'
