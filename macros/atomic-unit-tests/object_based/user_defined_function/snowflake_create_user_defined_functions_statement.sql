{%- macro snowflake_create_user_defined_functions_statement(relation, ns) -%}

CREATE OR REPLACE FUNCTION {{ relation.include(database=(not temporary), schema=(not temporary)) }}()

RETURNS {{ ns.return_type }}
{% if ns.preferred_language != 'sql' %}
LANGUAGE  {{ ns.preferred_language }}
{% endif %}

{% if ns.preferred_language == 'python'  %}
RUNTIME_VERSION = '{{ ns.runtime_version }}'
HANDLER = '{{ ns.handler_name }}'
PACKAGES = {{ ns.packages }}

{% elif preferred_language == 'java'  %}
handler = {{ ns.handler_name }}
target_path = {{ ns.target_path }}
{% endif %}

AS

$$
{{ ns.test_sql }}
$$
{%- endmacro -%}
