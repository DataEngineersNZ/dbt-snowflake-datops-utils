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
                    {#- SHOW TASKS only supports LIKE (already case-insensitive, per Snowflake docs), not ILIKE.
                        LIKE wildcards ('_' and '%') mean the pattern can also match unrelated tasks (e.g. a
                        task named 'load_orders' would also match 'loadxorders'), so the result is filtered
                        down to the exact task name below instead of trusting row 0 of the SHOW output. -#}
                    {% set state_query %}
                        show tasks like '{{ node.name }}' in schema {{ target.database }}.{{ node.schema }}
                        ->>
                        select "state" as state
                        from $1
                        where upper("name") = upper('{{ node.name }}')
                    {% endset %}
                    {% set state_results = run_query(state_query) %}

                    {% if not state_results or state_results | length == 0 %}
                        {{ exceptions.raise_compiler_error("enable_dependent_tasks: task " ~ task_name ~ " was not found via SHOW TASKS in schema " ~ target.database ~ "." ~ node.schema ~ ". Cannot verify its state before enabling dependents.") }}
                    {% endif %}

                    {% set task_state = state_results[0][0] | upper %}
                    {% if task_state == 'SUSPENDED' %}
                        {{ log("Enabling task and dependent tasks: " ~ task_name, info=True) }}
                        {% call statement('enable_dependent_tasks') %}
                            select system$task_dependents_enable('{{ task_name }}');
                        {% endcall %}
                    {% else %}
                        {{ log("Skipping enable_dependent_tasks for " ~ task_name ~ ": task is not suspended (current state: " ~ task_state ~ "). This is expected during partial runs where the task was not recreated.", info=True) }}
                    {% endif %}
                {% endfor %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}