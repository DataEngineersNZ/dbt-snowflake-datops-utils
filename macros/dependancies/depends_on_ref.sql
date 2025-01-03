{% macro depends_on_ref(include_for, model) -%}
{%- if include_for == 'docs' -%}
    {%- if flags.WHICH == 'generate' -%}
       --depends_on: {{ ref(model) }}
    {%- endif -%}
{%- elif include_for == 'run' -%}
    {%- if flags.WHICH in ('run', 'test', 'compile') -%}
       --depends_on: {{ ref(model) }}
    {%- endif -%}
{%- elif include_for == 'all' -%}
    --depends_on: {{ ref(model) }}
{%- endif -%}
{%- endmacro -%}
