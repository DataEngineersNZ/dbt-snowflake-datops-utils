{%- macro snowflake_create_user_defined_functions_statement(relation, preferred_language, return_type, sdk_version, import_Path, packages, handler_name, imports, target_path,runtime_version, sql) -%}

CREATE OR REPLACE FUNCTION {{ relation.include(database=(not temporary), schema=(not temporary)) }}()

RETURNS {{ return_type }}
{% if preferred_language != 'sql' %}
LANGUAGE  {{ preferred_language }}
{% endif %}

{% if preferred_language == 'python'  %}
RUNTIME_VERSION = '{{ runtime_version }}'
HANDLER = '{{ handler_name }}'
PACKAGES = {{ packages }}

{% elif preferred_language == 'java'  %}
handler = {{ handler_name }}
target_path = {{ target_path }}
{% endif %}

AS

$$
{{ sql }}
$$
{%- endmacro -%}