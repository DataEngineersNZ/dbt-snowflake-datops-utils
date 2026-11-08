{#
  Asserts apply_data_metric_functions actually set DATA_METRIC_SCHEDULE to the expected
  value for both testable tiers of the fallback chain, using the `schedule` column already
  exposed by INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES (the same table function the
  other two assert_dmf_attached_to_* tests use), rather than SHOW PARAMETERS (which isn't
  composable into a single SELECT the way a dbt singular test requires):
  - test_dmf_source: no model-level override, so falls back to the project-wide
    dmf_schedule var ('15 MINUTE', set in integration_tests/dbt_project.yml)
  - test_dmf_custom_target: model-level meta.dmf_schedule override ('30 MINUTE')

  The hardcoded '60 MINUTE' default (the third tier, used when neither a model override
  nor the var is set) is not exercised here: this project always sets the dmf_schedule var
  for every model, so no fixture is in a position to reach the hardcoded fallback without a
  third, separately var-scoped project -- out of scope for this integration suite.

  A dbt test must return 0 rows to pass. This returns one row per relation whose actual
  schedule doesn't match what was expected for its tier.
#}
with expected_schedules as (
    select '{{ ref("test_dmf_source") }}' as relation_name, '15 MINUTE' as expected_schedule
    union all
    select '{{ ref("test_dmf_custom_target") }}' as relation_name, '30 MINUTE' as expected_schedule
),

actual_schedules_source as (
    select distinct schedule
    from table(
        {{ target.database }}.information_schema.data_metric_function_references(
            ref_entity_name => '{{ ref("test_dmf_source") }}',
            ref_entity_domain => 'view'
        )
    )
),

actual_schedules_custom_target as (
    select distinct schedule
    from table(
        {{ target.database }}.information_schema.data_metric_function_references(
            ref_entity_name => '{{ ref("test_dmf_custom_target") }}',
            ref_entity_domain => 'view'
        )
    )
)

select expected_schedules.relation_name, expected_schedules.expected_schedule
from expected_schedules
where (
    expected_schedules.relation_name = '{{ ref("test_dmf_source") }}'
    and not exists (select 1 from actual_schedules_source where schedule = expected_schedules.expected_schedule)
) or (
    expected_schedules.relation_name = '{{ ref("test_dmf_custom_target") }}'
    and not exists (select 1 from actual_schedules_custom_target where schedule = expected_schedules.expected_schedule)
)
