-- Assert: invalid numeric date returns NULL
select * from {{ ref('test_parse') }}
where num_to_date_invalid is not null
