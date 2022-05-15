{% macro grant_schema_ownership_access(schemas, rolename, include_future_grants) %}
{% for current in schemas %}
    {% do log("Adding Ownership rights on " + current + " for " + rolename, info=True) %}
    GRANT USAGE ON SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT OWNERSHIP ON SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL STAGES IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL FILE FORMATS IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL FUNCTIONS IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL SEQUENCES IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL EXTERNAL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL MATERIALIZED VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL PROCEDURES IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL STREAMS IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    GRANT OWNERSHIP ON ALL TASKS IN SCHEMA {{ current }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
    
    {% if include_future_grants %}
    GRANT SELECT ON FUTURE VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON FUTURE MATERIALIZED VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON FUTURE TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};   
    GRANT SELECT ON FUTURE EXTERNAL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};    
    GRANT INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    {% endif %}
{% endfor %}    
{% endmacro %}
