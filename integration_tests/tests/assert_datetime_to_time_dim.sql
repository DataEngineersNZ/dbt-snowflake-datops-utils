-- Assert: datetime_to_time_dim produces HHMI string
select * from {{ ref('test_modelling') }}
where datetime_to_time_result != '1430'
