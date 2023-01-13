{%- macro dimension_id(field_list) -%}
{% set default_null_value = "" %}
{%- set fields = [] -%}

{%- for field in field_list -%}
    
   {%- do fields.append(
        "COALESCE(CAST(" ~ field ~ " AS " ~ dbt.type_string() ~ "), '" ~ default_null_value  ~"')"
    ) -%}

    {%- if not loop.last %}
        {%- do fields.append("'_'") -%}
    {%- endif -%}

{%- endfor -%}

REPLACE({{ dbt.concat(fields) }}, ' ', '')

{%- endmacro -%}
