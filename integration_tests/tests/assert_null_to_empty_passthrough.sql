-- Assert: null_to_empty_string passes through non-NULL
select * from {{ ref('test_parse') }}
where null_to_empty_passthrough != 'hello'
