{#
  Detect whether the current dbt invocation is `dbt docs generate` (vs. `run`/`build`/`test`/`compile`).

  flags.WHICH alone is not reliable for this: dbt-core reports 'generate' for `dbt docs generate`,
  but on dbt Fusion flags.WHICH reports 'compile' for BOTH `dbt compile` and `dbt docs generate`, so
  it can't distinguish the two there. As a second signal, the actual subcommand is parsed positionally
  out of the raw invocation command line (the executable token, then the following non-flag tokens),
  rather than substring-searching the whole command line -- a substring search would false-positive on
  something like `dbt run --vars '{"note":"docs generate"}'`.
#}
{% macro is_docs_generate_invocation(which, invocation_command) %}
    {%- set cmd_parts = (invocation_command or '').split() -%}
    {%- set subcommand_parts = [] -%}
    {%- set ns = namespace(found_exe=false, past_subcommand=false) -%}
    {%- for part in cmd_parts -%}
        {%- if not ns.found_exe -%}
            {%- if part in ['dbt', 'dbt.exe'] or part.endswith('/dbt') or part.endswith('dbt.exe') -%}
                {%- set ns.found_exe = true -%}
            {%- endif -%}
        {%- elif not ns.past_subcommand -%}
            {%- if part.startswith('-') -%}
                {%- set ns.past_subcommand = true -%}
            {%- else -%}
                {%- do subcommand_parts.append(part) -%}
            {%- endif -%}
        {%- endif -%}
    {%- endfor -%}
    {{ return(which == 'generate' or subcommand_parts == ['docs', 'generate']) }}
{% endmacro %}
