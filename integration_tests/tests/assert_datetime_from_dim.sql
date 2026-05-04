-- Assert: datetime_from_dim reconstructs the correct timestamp
select * from {{ ref('test_modelling') }}
where datetime_from_dim_result != '2024-03-15 14:30:00'::timestamp_ntz
