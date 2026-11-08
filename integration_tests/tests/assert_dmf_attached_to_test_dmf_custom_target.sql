{#
  Asserts apply_data_metric_functions actually attached the custom DMF (test_custom_dmf)
  to test_dmf_custom_target via the model-level `meta.dmf_custom` path -- a direct
  regression test for custom DMF attachment (builtins.ref() resolution to the DMF's real
  relation, DAG ordering so the DMF exists before the ALTER runs, and the custom-DMF ALTER
  syntax).

  Uses ref('test_dmf_custom_target') (not a hardcoded relation name) so dbt records a DAG
  dependency on the model -- without it, dbt build could run this test before the model
  (and its post-hook) has even run.

  A dbt test must return 0 rows to pass. This returns one row if the custom DMF is missing
  from test_dmf_custom_target's attached DMFs.
#}
with attached_dmfs as (
    select metric_name
    from table(
        {{ target.database }}.information_schema.data_metric_function_references(
            ref_entity_name => '{{ ref('test_dmf_custom_target') }}',
            ref_entity_domain => 'view'
        )
    )
)

select 'TEST_CUSTOM_DMF' as missing_dmf
where not exists (
    select 1
    from attached_dmfs
    where metric_name = 'TEST_CUSTOM_DMF'
)
