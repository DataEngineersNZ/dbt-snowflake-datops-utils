{#
  Asserts apply_data_metric_functions actually attached the expected system DMFs to
  test_dmf_source -- including the dmf_test_status accepted_values DMF, which uses STRING
  enum values ('open', 'closed') and is a direct regression test for the SQL-quoting bug
  fixed in this macro: unquoted string literals in the generated `IN (...)` clause
  previously produced invalid SQL and made the post-hook fail outright.

  A dbt test must return 0 rows to pass. This returns one row per expected DMF binding
  that is missing.
#}
with expected_dmfs as (
    select column1 as metric_name
    from (values ('NULL_COUNT'), ('DUPLICATE_COUNT'), ('ACCEPTED_VALUES'))
),

attached_dmfs as (
    select metric_name
    from table(
        {{ target.database }}.information_schema.data_metric_function_references(
            ref_entity_name => '{{ target.database }}.{{ target.schema }}.TEST_DMF_SOURCE',
            ref_entity_domain => 'view'
        )
    )
)

select expected_dmfs.metric_name as missing_dmf
from expected_dmfs
left join attached_dmfs on attached_dmfs.metric_name = expected_dmfs.metric_name
where attached_dmfs.metric_name is null
