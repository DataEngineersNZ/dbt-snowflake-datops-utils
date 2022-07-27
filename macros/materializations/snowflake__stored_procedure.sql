/*
  This materialization is used for creating stored procedure objects.
  The idea behind this materialization is for ability to define CREATE STORED PROCEDURE statements and have DBT the necessary logic
  of deploying the stored procedure in a consistent manner and logic.
  Adapted from https://github.com/venkatra/dbt_hacks

*/
{%- macro snowflake__stored_procedure() -%}
  {%- set preferred_language = config.get('preferred_language', default=SQL) -%}
  {%- set parameters = config.get('parameters', default={}) -%}
  {%- set identifier = config.get('override_name', default=model['alias'] ) -%}
  {%- set return_type = config.get('return_type', default={} ) -%}

  {%- set target_relation = api.Relation.create( identifier=identifier, schema=schema, database=database) -%}

  {%- set has_transactional_hooks = (hooks | selectattr('transaction', 'equalto', True) | list | length) > 0 %}

  -- setup
  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- BEGIN happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

      --------------------------------------------------------------------------------------------------------------------
  -- build model

  {% call statement('main') -%}
    {{ dbt_dataengineers_utils.create_storedprocedure_stmt_fromfile(target_relation, preferred_language, parameters, return_type, sql) }}
  {%- endcall %}

      --------------------------------------------------------------------------------------------------------------------
  -- build model
  {{ run_hooks(post_hooks, inside_transaction=True) }}

  -- `COMMIT` happens here
  {{ adapter.commit() }}
  {{ run_hooks(post_hooks, inside_transaction=False) }}

  -- return
  {{ return({'relations': [target_relation]}) }}

{%- endmacro -%}
 