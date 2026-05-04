-- Assert: time_key produces HHMI string
select * from {{ ref('test_modelling') }}
where time_key_result != '1430'
