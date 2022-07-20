{%- materialization stage, adapter='snowflake' -%}
  {{ return(dbt_dataengineers_utils.snowflake__stage()) }}
{%- endmaterialization -%}