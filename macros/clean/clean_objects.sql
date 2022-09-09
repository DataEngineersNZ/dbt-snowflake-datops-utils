{% macro clean_objects(database=target.database, check_schemas=True, check_functions=True, check_tasks=True, check_streams=True, check_stages=True, check_tables_and_views=True, dry_run=True) %}
    {%if execute %}
        {% if flags.WHICH in ('run', 'run-operation') %}
            {% if check_schemas %}
                {% do dbt_dataengineers_utils.clean_schemas(database, dry_run) %}
            {% endif %}
            {% if check_functions %}
                {% do dbt_dataengineers_utils.clean_functions(database, dry_run) %}
            {% endif %}
            {% if check_tasks %}
                {% do dbt_dataengineers_utils.clean_generic("TASK", database, dry_run) %}
            {% endif %}
            {% if check_streams %}
                {% do dbt_dataengineers_utils.clean_generic("STREAM", database, dry_run) %}
            {% endif %}
            {% if check_stages %}
                {% do dbt_dataengineers_utils.clean_generic("STAGE", database, dry_run) %}
            {% endif %}
            {% if check_tables_and_views %}
                {% do dbt_dataengineers_utils.clean_models(database, dry_run) %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}
