-- Assert: dimension_id concatenates fields with underscore, no spaces
select * from {{ ref('test_modelling') }}
where dimension_id_result != 'ABC_123'
