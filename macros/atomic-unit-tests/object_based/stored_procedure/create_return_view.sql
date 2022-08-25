{%- macro create_return_view(mock_model_relation) %}
    {% set execute_sql = "CALL " ~ mock_model_relation ~ "();" %}
    {% set results = run_query(execute_sql) %}
    {% set view_data = namespace(value="") %}
    {% for record in results %}
        {% set view_data.value = view_data.value ~ dbt_dataengineers_utils.create_select_row(results.columns, record.values()) %}
        {% if not loop.last %}
            {% set view_data.value = view_data.value ~ "
UNION ALL
" %}
        {% endif %}
    {% endfor %}
    {{ return(view_data.value) }}
{% endmacro -%}

