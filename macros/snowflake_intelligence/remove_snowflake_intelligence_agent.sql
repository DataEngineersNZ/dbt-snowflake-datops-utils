{% macro remove_snowflake_intelligence_agent(si_name, agents) %}
    {# Detaches one or more Cortex Agents from a Snowflake Intelligence (CoWork) object via
       ALTER SNOWFLAKE INTELLIGENCE <si_name> DROP AGENT <db>.<schema>.<agent>. Unlike REVOKE, this is NOT
       idempotent in Snowflake -- dropping an agent that isn't currently attached raises "<agent> was not
       found in <si_name>" (confirmed live), so current attachments are checked first via SHOW AGENTS IN
       SNOWFLAKE INTELLIGENCE and only agents currently attached are dropped. A duplicate entry within
       `agents` itself (including a case-variant of one already queued) is also skipped rather than
       queued twice -- the first DROP changes the account's actual attachment state before the second
       one runs, so queuing the same DROP statement twice would hit the same "not found" error.

       `agents` is a list of 'SCHEMA.AGENT_NAME' strings, same convention as
       add_snowflake_intelligence_agent. `si_name` is the bare name of the Snowflake Intelligence object
       itself -- an account-level object, never qualified with target.database. #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping remove_snowflake_intelligence_agent: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping remove_snowflake_intelligence_agent: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if agents | length == 0 %}
        {% do log('remove_snowflake_intelligence_agent: no agents supplied for ' ~ si_name, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% set existing_query %}
        show agents in snowflake intelligence {{ si_name }};
    {% endset %}
    {% set existing_rows = run_query(existing_query) %}
    {% set existing_agents = [] %}
    {% for row in existing_rows %}
        {% do existing_agents.append((row.database_name ~ '.' ~ row.schema_name ~ '.' ~ row.name) | upper) %}
    {% endfor %}

    {% set drop_statements = [] %}
    {% set queued = [] %}
    {% for agent in agents %}
        {% set fqn = target.database ~ '.' ~ agent %}
        {% set fqn_upper = fqn | upper %}
        {% if fqn_upper in existing_agents and fqn_upper not in queued %}
            {% do drop_statements.append('alter snowflake intelligence ' ~ si_name ~ ' drop agent ' ~ fqn ~ ';') %}
            {% do queued.append(fqn_upper) %}
        {% elif fqn_upper in queued %}
            {% do log('remove_snowflake_intelligence_agent: ' ~ fqn ~ ' already queued to detach from ' ~ si_name ~ ', skipping duplicate', info=True) %}
        {% else %}
            {% do log('remove_snowflake_intelligence_agent: ' ~ fqn ~ ' not attached to ' ~ si_name ~ ', skipping', info=True) %}
        {% endif %}
    {% endfor %}

    {% if drop_statements | length == 0 %}
        {% do log('remove_snowflake_intelligence_agent: no changes required for ' ~ si_name, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('remove_snowflake_intelligence_agent summary: ' ~ (drop_statements | length) ~ ' agent(s) to detach from ' ~ si_name, info=True) %}
    {% for stmt in drop_statements %}
        {% do log(stmt, info=True) %}
        {% do run_query(stmt) %}
    {% endfor %}
    {% do log('remove_snowflake_intelligence_agent: completed detaching agents from ' ~ si_name, info=True) %}
{% endmacro %}
