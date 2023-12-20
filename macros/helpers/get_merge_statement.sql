{%- macro get_merge_statement(source, destination_table, destination_schema, unique_key, predicates=none) -%}

{%- set source_relation = api.Relation.create(identifier=source.identifier, schema=source.schema, database=database) -%}
{%- set destination_relation = adapter.get_relation( identifier=destination_table, schema=destination_schema, database=database) -%}
{%- set dest_columns = adapter.get_columns_in_relation(destination_relation) -%}
{{ get_merge_sql(destination_relation, source_relation, unique_key, dest_columns, predicates)  | replace("begin;", "") | replace("commit;", "") }}
{%- endmacro -%}
