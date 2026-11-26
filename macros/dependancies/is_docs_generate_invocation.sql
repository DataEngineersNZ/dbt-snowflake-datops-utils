{#
  Detect whether the current dbt invocation is `dbt docs generate` (vs. `run`/`build`/`test`/`compile`).

  flags.WHICH alone is not reliable for this: dbt-core reports 'generate' for `dbt docs generate`,
  but on dbt Fusion flags.WHICH reports 'compile' for BOTH `dbt compile` and `dbt docs generate`
  (Fusion internally rewrites a docs-generate invocation's command to a synthesized Compile pass), so
  it can't distinguish the two there. As a second signal, the leading run of non-flag tokens in the raw
  invocation command line is checked for a trailing `docs generate` pair -- not anchored to a specific
  executable name/path (which can't be assumed stable across CLI, `snow dbt execute`, or a managed
  execution environment like dbt Projects on Snowflake), and not a substring search across the whole
  command line, which would false-positive on something like `dbt run --vars '{"note":"docs generate"}'`
  (the leading-run scan stops at the first `--vars` flag token, well before that text).
#}
{% macro is_docs_generate_invocation(which, invocation_command) %}
    {%- set cmd_parts = (invocation_command or '').split() -%}
    {%- set leading_parts = [] -%}
    {%- set ns = namespace(past_leading_run=false) -%}
    {%- for part in cmd_parts -%}
        {%- if not ns.past_leading_run -%}
            {%- if part.startswith('-') -%}
                {%- set ns.past_leading_run = true -%}
            {%- else -%}
                {%- do leading_parts.append(part) -%}
            {%- endif -%}
        {%- endif -%}
    {%- endfor -%}
    {%- set n = leading_parts | length -%}
    {{ return(which == 'generate' or (n >= 2 and leading_parts[n - 2] == 'docs' and leading_parts[n - 1] == 'generate')) }}
{% endmacro %}
