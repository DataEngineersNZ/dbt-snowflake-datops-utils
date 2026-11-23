{% macro add_snowflake_intelligence_agent(si_name, agents) %}
    {# Attaches one or more Cortex Agents to a Snowflake Intelligence (CoWork) object via
       ALTER SNOWFLAKE INTELLIGENCE <si_name> ADD AGENT <db>.<schema>.<agent>. Unlike GRANT, this is NOT
       idempotent in Snowflake -- re-adding an already-attached agent raises "<agent> is already present
       in <si_name>" (confirmed live), so existing attachments are checked first via SHOW AGENTS IN
       SNOWFLAKE INTELLIGENCE and only agents not already attached are added.

       `agents` is a list of 'SCHEMA.AGENT_NAME' strings identifying agents in the current
       target.database (mirroring grant_database_role_object's `objects` convention) -- not pre-qualified
       with the database name. `si_name` is the bare name of the Snowflake Intelligence object itself
       (e.g. SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT) -- it is an account-level object, not database-scoped,
       so it is never qualified with target.database. #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping add_snowflake_intelligence_agent: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}
    {% if not execute %}
        {% do log('Skipping add_snowflake_intelligence_agent: compile phase only', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if agents | length == 0 %}
        {% do log('add_snowflake_intelligence_agent: no agents supplied for ' ~ si_name, info=True) %}
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

    {% set add_statements = [] %}
    {% for agent in agents %}
        {% set fqn = target.database ~ '.' ~ agent %}
        {% if (fqn | upper) in existing_agents %}
            {% do log('add_snowflake_intelligence_agent: ' ~ fqn ~ ' already attached to ' ~ si_name ~ ', skipping', info=True) %}
        {% else %}
            {% do add_statements.append('alter snowflake intelligence ' ~ si_name ~ ' add agent ' ~ fqn ~ ';') %}
        {% endif %}
    {% endfor %}

    {% if add_statements | length == 0 %}
        {% do log('add_snowflake_intelligence_agent: no changes required for ' ~ si_name, info=True) %}
        {% do return(none) %}
    {% endif %}

    {% do log('add_snowflake_intelligence_agent summary: ' ~ (add_statements | length) ~ ' agent(s) to attach to ' ~ si_name, info=True) %}
    {% for stmt in add_statements %}
        {% do log(stmt, info=True) %}
        {% do run_query(stmt) %}
    {% endfor %}
    {% do log('add_snowflake_intelligence_agent: completed attaching agents to ' ~ si_name, info=True) %}
{% endmacro %}
