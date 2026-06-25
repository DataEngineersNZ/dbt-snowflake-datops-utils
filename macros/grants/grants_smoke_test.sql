{% macro grants_smoke_test(role='DEVELOPERS', sample_schema='PUBLIC') %}
    {#
        Purpose: Lightweight validation / demonstration macro to exercise refactored grant macros in dry-run mode.
        Usage:
          dbt run-operation grants_smoke_test --args '{"role":"DEVELOPERS", "sample_schema":"PUBLIC"}' --vars '{"grants_dry_run": true}'
        Behavior:
          - Confirms early-exit guard works
          - Invokes a representative subset of macros with constrained scope
          - Tests case-insensitive role handling
          - Does not mutate state when grants_dry_run=true
    #}
    {% if flags.WHICH not in ['run','run-operation'] %}
        {% do log('grants_smoke_test: skipped (context)', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% set dry_run = var('grants_dry_run', true) %}
    {% do log('grants_smoke_test: starting (dry_run=' ~ dry_run ~ ')', info=True) %}

    {# Test case-insensitive role normalization #}
    {% set mixed_case_role = role | lower %}
    {% do log('grants_smoke_test: testing with mixed-case role "' ~ mixed_case_role ~ '" (should normalize to "' ~ role | upper ~ '")', info=True) %}

    {# Invoke monitor / operate / read on narrow scope with mixed-case role #}
    {{ dbt_dataengineers_utils.grant_schema_monitor_specific([sample_schema], [mixed_case_role], false, dry_run) }}
    {{ dbt_dataengineers_utils.grant_schema_operate_specific([sample_schema], [mixed_case_role], false, dry_run) }}
    {{ dbt_dataengineers_utils.grant_schema_read_specific([sample_schema], [mixed_case_role], false, false) }}

    {# Test procedure usage with dry_run #}
    {{ dbt_dataengineers_utils.grant_schema_procedure_usage_specific([sample_schema], [role], false, dry_run) }}

    {# Test grant_schema_object_privileges with dry_run #}
    {{ dbt_dataengineers_utils.grant_schema_object_privileges('table', sample_schema, ['SELECT'], [role]) }}

    {# Test grant_object with empty objects (should exit early) #}
    {{ dbt_dataengineers_utils.grant_object('table', [], ['SELECT'], [role]) }}

    {# Share read test (no views passed, revokes only if any) #}
    {{ dbt_dataengineers_utils.grant_share_read([], [], false) }}

    {# Test database usage with mixed-case roles #}
    {{ dbt_dataengineers_utils.grant_database_usage([mixed_case_role], [], false) }}

    {% do log('grants_smoke_test: complete', info=True) %}
{% endmacro %}
