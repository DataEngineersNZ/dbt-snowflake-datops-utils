{% macro grants_smoke_test(role='DEVELOPERS', sample_schema='PUBLIC') %}
    {#
        Purpose: Lightweight validation / demonstration macro to exercise refactored grant macros in dry-run mode.
        Usage:
          dbt run-operation grants_smoke_test --args '{"role":"DEVELOPERS", "sample_schema":"PUBLIC"}' --vars '{"grants_dry_run": true}'
        Behavior:
          - Confirms early-exit guard works
          - Invokes a representative subset of macros with constrained scope
          - Does not mutate state when grants_dry_run=true
    #}
    {% if flags.WHICH not in ['run','run-operation'] %}
        {% do log('grants_smoke_test: skipped (context)', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% set dry_run = var('grants_dry_run', true) %}
    {% do log('grants_smoke_test: starting (dry_run=' ~ dry_run ~ ')', info=True) %}

    {# Minimal object lists for grant_object test (uses SELECT privilege on a non-existent object will simply error if executed; rely on dry-run). #}
    {% set test_objects = [] %}

    {# Invoke monitor / operate / read on narrow scope #}
    {{ dbt_dataengineers_utils.grant_schema_monitor_specific([sample_schema], [role], true, dry_run) }}
    {{ dbt_dataengineers_utils.grant_schema_operate_specific([sample_schema], [role], true, dry_run) }}
    {{ dbt_dataengineers_utils.grant_schema_read_specific([sample_schema], [role], false, false) }}

    {# Share read test (no views passed, revokes only if any) #}
    {{ dbt_dataengineers_utils.grant_share_read([], [], false) }}

    {% do log('grants_smoke_test: complete', info=True) %}
{% endmacro %}
