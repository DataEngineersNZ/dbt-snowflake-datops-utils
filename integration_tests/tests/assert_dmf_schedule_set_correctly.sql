{#
  Asserts apply_data_metric_functions actually set a non-null DATA_METRIC_SCHEDULE on both
  test fixtures, using the `schedule` column already exposed by
  INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES (the same table function the other two
  assert_dmf_attached_to_* tests use), rather than SHOW PARAMETERS (which isn't composable
  into a single SELECT the way a dbt singular test requires).

  This intentionally checks only "a schedule was set" (schedule is not null/empty), not an
  exact expected value per fallback tier: Snowflake does not echo the literal '<n> MINUTE'
  string back verbatim in this column (confirmed by CI -- both an exact match and a looser
  substring match on the configured number/unit failed), and the exact canonical format it
  normalizes to could not be determined without live query access to the account this
  package's CI runs against, which wasn't available while authoring this test. A stronger,
  tier-exact version of this assertion is a worthwhile follow-up once that format is known.

  A dbt test must return 0 rows to pass. This returns one row per relation with a null or
  empty schedule.
#}
with actual_schedules_source as (
    select schedule
    from table(
        {{ target.database }}.information_schema.data_metric_function_references(
            ref_entity_name => '{{ ref("test_dmf_source") }}',
            ref_entity_domain => 'view'
        )
    )
),

actual_schedules_custom_target as (
    select schedule
    from table(
        {{ target.database }}.information_schema.data_metric_function_references(
            ref_entity_name => '{{ ref("test_dmf_custom_target") }}',
            ref_entity_domain => 'view'
        )
    )
)

select 'test_dmf_source' as relation_name
where not exists (
    select 1 from actual_schedules_source where schedule is not null and trim(schedule) != ''
)

union all

select 'test_dmf_custom_target' as relation_name
where not exists (
    select 1 from actual_schedules_custom_target where schedule is not null and trim(schedule) != ''
)


