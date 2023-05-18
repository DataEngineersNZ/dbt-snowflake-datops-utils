{%- macro get_default_merge_statement(source, destination_table, destination_schema, unique_key, predicates=none) -%}

{%- set source_relation = load_relation(source) -%}
{%- set destination_relation = adapter.get_relation( identifier=destination_table, schema=destination_schema, database=database) -%} 
{%- set dest_columns = adapter.get_columns_in_relation(destination_relation) -%}
{{ default__get_merge_sql(destination_relation, source_relation, unique_key, dest_columns, predicates) }}
{%- endmacro -%}
