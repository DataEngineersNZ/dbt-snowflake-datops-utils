{% macro clean_objects(database=target.database, clean_targets=['local-dev', 'unit-test', 'test', 'prod'], object_types= ['schemas', 'functions_and_procedures', 'tasks', 'streams', 'stages', 'tables_and_views', 'alerts', 'file_formats']) %}
    {%if execute %}
        {% if flags.WHICH in ('run', 'run-operation') %}
            {% if target.name in clean_targets %}
                {% set dry_run = false %}
            {% else %}
                {% set dry_run = true %}
            {% endif %}
            {% if 'schemas' in object_types %}
                {% do dbt_dataengineers_utils.clean_schemas(database, dry_run) %}
            {% endif %}
            {% if 'functions_and_procedures' in object_types %}
                {% do dbt_dataengineers_utils.clean_functions(database, dry_run) %}
            {% endif %}
            {% if 'tasks' in object_types %}
                {% do dbt_dataengineers_utils.clean_generic("TASK", database, dry_run) %}
            {% endif %}
            {% if 'streams' in object_types %}
                {% do dbt_dataengineers_utils.clean_generic("STREAM", database, dry_run) %}
            {% endif %}
             {% if 'stages' in object_types %}
                {% do dbt_dataengineers_utils.clean_generic("STAGE", database, dry_run) %}
            {% endif %}
            {% if 'alerts' in object_types %}
                {% do dbt_dataengineers_utils.clean_generic("ALERT", database, dry_run) %}
            {% endif %}
            {% if 'file_formats' in object_types %}
                {% do dbt_dataengineers_utils.clean_generic("FILE FORMAT", database, dry_run) %}
            {% endif %}
            {% if 'network_rules' in object_types %}
                {% do dbt_dataengineers_utils.clean_generic("NETWORK RULE", database, dry_run) %}
            {% endif %}
            {% if 'secrets' in object_types %}
                {% do dbt_dataengineers_utils.clean_generic("SECRET", database, dry_run) %}
            {% endif %}
            {% if 'tables_and_views' in object_types %}
                {% do dbt_dataengineers_utils.clean_models(database, dry_run) %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}
