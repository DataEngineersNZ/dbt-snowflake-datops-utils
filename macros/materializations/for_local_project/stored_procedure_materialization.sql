{%- materialization stored_procedure, adapter='snowflake' -%}
  {{ return(dbt_dataengineers_utils.snowflake__stored_procedure()) }}
{%- endmaterialization -%}