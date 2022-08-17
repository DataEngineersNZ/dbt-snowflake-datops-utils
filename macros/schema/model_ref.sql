{%- macro model_ref(model_name) -%}
{%- set destination_relation = api.Relation.create( identifier=model_name, schema=schema, database=database) -%} 
{{ destination_relation.include(database=(not temporary), schema=(not temporary)) }}
{%- endmacro -%}