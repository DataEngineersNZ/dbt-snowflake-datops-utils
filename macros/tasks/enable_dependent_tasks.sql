{% macro enable_dependent_tasks(root_task, enabled_targets) %}
    {%- if execute -%}
        {% if target.name in enabled_targets -%}
            {% if flags.WHICH in ['run', 'build', 'run-operation'] %}
                {% set nodes = graph.nodes.values() if graph.nodes else [] %}
                {% set candidate_nodes = nodes | selectattr("name", "equalto", root_task | lower) %}
                {% set matching_nodes = [] %}
                {% for node in candidate_nodes %}
                    {% if node.config.get("materialized") == "task" %}
                        {% do matching_nodes.append(node) %}
                    {% endif %}
                {% endfor %}
                {% for node in matching_nodes %}
                    {% set task_name = target.database + "." + node.schema + "." + node.name %}
                    {{ log("Enabling task and dependant tasks: " ~ task_name, info=True) }}
                    {% call statement('enable_depenant_tasks') %}
                        SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('{{task_name}}');
                    {% endcall %}
                {% endfor %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}