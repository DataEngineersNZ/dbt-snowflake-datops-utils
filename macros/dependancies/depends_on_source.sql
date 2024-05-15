{% macro depends_on_source(include_for, schema, model) -%}
{% set depends_on = "" %}
{% if include_for == 'docs' %}
    {% if flags.WHICH == 'generate' %}
        {% set depends_on = "--depends_on: {{ source('" ~ schema ~ "', '" ~  model ~ "') }}" %}
    {% endif %}
{% elif include_for == 'run' %}
    {% if flags.WHICH in ('run', 'test', 'compile') %}
        {% set depends_on = "--depends_on: {{ source('" ~ schema ~ "', '" ~  model ~ "') }}" %}
    {% endif %}
{% elif include_for == 'all' %}
    {% set depends_on = "--depends_on: {{ source('" ~ schema ~ "', '" ~  model ~ "') }}" %}
{% endif %}
{{ depends_on }}
{%- endmacro -%}
