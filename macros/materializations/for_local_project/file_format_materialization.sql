{%- materialization file_format, adapter='snowflake' -%}
  {{ return(dbt_dataengineers_utils.snowflake__file_format()) }}
{%- endmaterialization -%}