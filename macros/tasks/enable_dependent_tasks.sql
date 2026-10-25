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
                    {% set state_query %}
                        show tasks ilike '{{ node.name }}' in schema {{ target.database }}.{{ node.schema }}
                        ->>
                        select "state" as state
                        from $1
                    {% endset %}
                    {% set state_results = run_query(state_query) %}
                    {% set task_state = (state_results[0][0] | upper) if state_results and state_results | length > 0 else none %}
                    {% if task_state == 'SUSPENDED' %}
                        {{ log("Enabling task and dependant tasks: " ~ task_name, info=True) }}
                        {% call statement('enable_depenant_tasks') %}
                            SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('{{task_name}}');
                        {% endcall %}
                    {% else %}
                        {{ log("Skipping enable_dependent_tasks for " ~ task_name ~ ": task is not suspended (current state: " ~ (task_state or 'UNKNOWN') ~ "). This is expected during partial runs where the task was not recreated.", info=True) }}
                    {% endif %}
                {% endfor %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}