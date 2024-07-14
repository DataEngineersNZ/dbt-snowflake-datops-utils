{% macro depends_on_source(include_for, schema, model, include_database=true) -%}
{%- if include_for == 'docs' -%}
    {%- if flags.WHICH == 'generate' -%}
--depends_on: {{ source(schema, model, include_database) }}
    {%- endif -%}
{%- elif include_for == 'run' -%}
    {%- if flags.WHICH in ('run', 'test', 'compile') -%}
--depends_on: {{ source(schema, model, include_database) }}
    {%- endif %}
{%- elif include_for == 'all' -%}
--depends_on: {{ source(schema, model, include_database) }}
{%- endif -%}
{%- endmacro -%}
