{% macro depends_on_source(include_for, schema, model, include_database=true) -%}
{% set ref_statements = [] %}
{%- if include_for == 'docs' -%}
    {%- if flags.WHICH == 'generate' -%}
       {%-  do ref_statements.append(model) -%}
    {%- endif -%}
{%- elif include_for == 'run' -%}
    {%- if flags.WHICH in ('run', 'test', 'compile') -%}
       {%-  do ref_statements.append(model) -%}
    {%- endif %}
{%- elif include_for == 'all' -%}
       {%-  do ref_statements.append(model) -%}
{%- endif -%}
{%- for depends_on in ref_statements %}
--depends_on: {{ source(schema, model, include_database) }}
{% endfor -%}
{%- endmacro -%}
