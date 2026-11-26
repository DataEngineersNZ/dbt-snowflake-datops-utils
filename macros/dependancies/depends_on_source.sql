{% macro depends_on_source(include_for, schema, model, include_database=true) -%}
{% set ref_statements = [] %}
{%- set is_docs_generate = flags.WHICH == 'generate' or 'docs generate' in (invocation_args_dict.get('invocation_command', '')) -%}
{%- if include_for == 'docs' -%}
    {%- if is_docs_generate -%}
       {%-  do ref_statements.append(model) -%}
    {%- endif -%}
{%- elif include_for == 'run' -%}
    {%- if flags.WHICH in ['run', 'build', 'test', 'compile'] and not is_docs_generate -%}
       {%-  do ref_statements.append(model) -%}
    {%- endif -%}
{%- elif include_for == 'all' -%}
       {%-  do ref_statements.append(model) -%}
{%- endif -%}
{%- for depends_on in ref_statements %}
--depends_on: {{ source(schema, model, include_database) }}
{% endfor -%}
{%- endmacro -%}
