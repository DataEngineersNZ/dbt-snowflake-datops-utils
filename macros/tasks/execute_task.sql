{% macro execute_task(task_name, enabled_targets) %}
    {%- if execute -%}
        {% if target.name in enabled_targets -%}
            {% if flags.WHICH == 'run' %}
                {% set nodes = graph.nodes.values() if graph.nodes else [] %}
                 {% set matching_nodes = nodes
                    | selectattr("name", "equalto", root_task | lower)
                    | selectattr("config.materialized", "equalto", "task")
                %}
                {% for node in matching_nodes %}
                    {% set task_name = target.database + "." + node.schema + "." + node.name %}
                    {{ log("Executing task: " ~ task_name, info=True) }}
                    {% call statement('enable_depenant_tasks') %}
                        execute task {{task_name}};
                    {% endcall %}
                {% endfor %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}