-- Fixture model for apply_data_metric_functions: exercises not_null, unique, and
-- accepted_values (both numeric and STRING enum values -- the STRING case is a direct
-- regression test for the SQL-quoting bug fixed when this macro was ported from a
-- consuming project: unquoted string literals in the generated `IN (...)` clause
-- previously produced invalid SQL and made the post-hook fail outright).
--
-- post-hook is set here (not in the schema YAML's model-level `config:` block) because
-- dbt-core doesn't reliably resolve package macro namespaces when a hook string is
-- rendered from a model-level YAML config -- the same {{ dbt_dataengineers_utils....() }}
-- pattern works fine from a SQL file's config() call or from dbt_project.yml.
{{ config(
    materialized='view',
    post_hook=["{{ dbt_dataengineers_utils.apply_data_metric_functions() }}"]
) }}

select 1 as dmf_test_id, 'open' as dmf_test_status, 1 as dmf_test_priority
union all
select 2 as dmf_test_id, 'closed' as dmf_test_status, 2 as dmf_test_priority
union all
select 3 as dmf_test_id, 'open' as dmf_test_status, 3 as dmf_test_priority
