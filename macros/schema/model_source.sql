{%- macro model_source(schema_name, model_name, include_database=false) -%}
{%- set source_relation = api.Relation.create( identifier=model_name, schema=schema_name, database=database) -%} 
{{ source_relation.include(database=include_database, schema=(not temporary)) }}
{%- endmacro -%}