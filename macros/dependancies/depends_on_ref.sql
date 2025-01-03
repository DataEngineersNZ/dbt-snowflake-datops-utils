{% macro depends_on_ref(include_for, model) -%}
{% set ref_statements = [] %}
{%- if include_for == 'docs' -%}
    {%- if flags.WHICH == 'generate' -%}
       {%-  do ref_statements.append(model) -%}
    {%- endif -%}
{%- elif include_for == 'run' -%}
    {%- if flags.WHICH in ('run', 'test', 'compile') -%}
       {%-  do ref_statements.append(model) -%}
    {%- endif -%}
{%- elif include_for == 'all' -%}
       {%-  do ref_statements.append(model) -%}
{%- endif -%}
{%- for depends_on in ref_statements %}
    -- depends_on: {{ ref(model) }}
{% endfor -%}
{%- endmacro -%}
