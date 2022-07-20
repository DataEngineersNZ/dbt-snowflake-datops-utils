{% macro snowflake__get_stream_build_plan(source_node) %}
    {% set build_plan = [] %}

    {# Setup our variables which are re-usable #}
    {%- set identifier = source_node.name -%}
    {%- set schema = source_node.schema -%}
    {%- set database = source_node.database -%}
    {%- set stream_name = dbt_dataengineers_utils.snowflake_get_stream_name(identifier) -%}

    {%- set current_target_relation = adapter.get_relation(database=database, schema=schema, identifier=identifier) -%}
    {%- set current_stream_relation = adapter.get_relation(database=database, schema=schema, identifier=stream_name) -%}

    {% if current_stream_relation is none and current_target_relation is not none%}
        {%- set new_stream_relation = api.Relation.create(schema=schema, identifier=stream_name) %}
        {% do build_plan.append(dbt_dataengineers_utils.snowflake_create_stream(new_stream_relation, current_target_relation)) %}
    {% endif %}

    {% do return(build_plan) %}
{% endmacro %}
