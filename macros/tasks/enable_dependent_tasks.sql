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
                        down to the exact task name below instead of trusting row 0 of the SHOW output.
                        The state check and the enable call are combined into a single Snowflake Scripting
                        anonymous block so they execute as one atomic statement: this avoids a race where the
                        task's state changes between a separate check and a separate enable call, and the
                        EXCEPTION handler treats "already started" (i.e. another process enabled it
                        concurrently) as a success instead of failing the run. -#}
                    {% set enable_sql %}
                        execute immediate $$
                        declare
                            v_state varchar default null;
                        begin
                            show tasks like '{{ node.name }}' in schema {{ target.database }}.{{ node.schema }};
                            select "state" into v_state
                            from table(result_scan(last_query_id()))
                            where upper("name") = upper('{{ node.name }}')
                            limit 1;

                            if (v_state is null) then
                                return 'MISSING';
                            end if;

                            if (upper(v_state) = 'SUSPENDED') then
                                call system$task_dependents_enable('{{ task_name }}');
                                return 'ENABLED';
                            else
                                return 'SKIPPED:' || v_state;
                            end if;
                        exception
                            when other then
                                if (contains(upper(sqlerrm), 'NOT SUSPENDED')) then
                                    return 'ENABLED_CONCURRENTLY';
                                end if;
                                raise;
                        end;
                        $$
                    {% endset %}
                    {% set enable_results = run_query(enable_sql) %}
                    {% set outcome = (enable_results[0][0] | string) if enable_results and enable_results | length > 0 else none %}

                    {% if outcome is none or outcome == 'MISSING' %}
                        {{ exceptions.raise_compiler_error("enable_dependent_tasks: task " ~ task_name ~ " was not found via SHOW TASKS in schema " ~ target.database ~ "." ~ node.schema ~ ". Cannot verify its state before enabling dependents.") }}
                    {% elif outcome in ['ENABLED', 'ENABLED_CONCURRENTLY'] %}
                        {{ log("Enabled task and dependent tasks: " ~ task_name, info=True) }}
                    {% elif outcome.startswith('SKIPPED:') %}
                        {{ log("Skipping enable_dependent_tasks for " ~ task_name ~ ": task is not suspended (current state: " ~ outcome[8:] ~ "). This is expected during partial runs where the task was not recreated.", info=True) }}
                    {% else %}
                        {{ exceptions.raise_compiler_error("enable_dependent_tasks: unexpected result '" ~ outcome ~ "' while enabling dependents for " ~ task_name) }}
                    {% endif %}
                {% endfor %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}