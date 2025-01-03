{%- macro get_default_merge_statement(source, destination_table, destination_schema, unique_key, predicates=none) -%}

{%- set source_relation = api.Relation.create(identifier=source.identifier, schema=source.schema, database=database) -%}
{%- set destination_relation = adapter.get_relation(identifier=destination_table, schema=destination_schema, database=database) -%}
{% if destination_relation != none %}
{%- set dest_columns = adapter.get_columns_in_relation(destination_relation) -%}
{{ default__get_merge_sql(destination_relation, source_relation, unique_key, dest_columns, predicates) }}
{% endif %}
{%- endmacro -%}
