{#
  Asserts apply_data_metric_functions actually attached the expected system DMFs to
  test_dmf_source -- including the dmf_test_status accepted_values DMF, which uses STRING
  enum values ('open', 'closed') and is a direct regression test for the SQL-quoting bug
  fixed in this macro: unquoted string literals in the generated `IN (...)` clause
  previously produced invalid SQL and made the post-hook fail outright.

  Uses ref('test_dmf_source') (not a hardcoded relation name) so dbt records a DAG
  dependency on the model -- without it, dbt build could run this test before the model
  (and its post-hook) has even run.

  Checks counts, not just metric-name presence: ACCEPTED_VALUES is expected on both
  dmf_test_status and dmf_test_priority, so a binding that silently failed on one of the
  two columns (while the other succeeded) would still be caught here, not just a complete
  absence of the metric.

  A dbt test must return 0 rows to pass. This returns one row per expected DMF binding
  whose actual attachment count is less than expected.
#}
with expected_dmfs as (
    select 'NULL_COUNT' as metric_name, 1 as expected_count
    union all
    select 'DUPLICATE_COUNT' as metric_name, 1 as expected_count
    union all
    select 'ACCEPTED_VALUES' as metric_name, 2 as expected_count
),

attached_dmfs as (
    select metric_name, count(*) as actual_count
    from table(
        {{ target.database }}.information_schema.data_metric_function_references(
            ref_entity_name => '{{ ref('test_dmf_source') }}',
            ref_entity_domain => 'view'
        )
    )
    group by metric_name
)

select
    expected_dmfs.metric_name,
    expected_dmfs.expected_count,
    coalesce(attached_dmfs.actual_count, 0) as actual_count
from expected_dmfs
left join attached_dmfs on attached_dmfs.metric_name = expected_dmfs.metric_name
where coalesce(attached_dmfs.actual_count, 0) < expected_dmfs.expected_count
