{% macro grant_schema_write_access(schemas, rolename, include_future_grants) %}
{% for current in schemas %}
    {% do log("Adding Write Access on " + current + " for " + rolename, info=True) %}
    GRANT USAGE ON SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT CREATE TABLE ON SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON ALL VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON ALL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON ALL EXTERNAL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    
    {% if include_future_grants %}
    GRANT SELECT ON FUTURE VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON FUTURE MATERIALIZED VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON FUTURE TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON FUTURE EXTERNAL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    {% endif %}
{% endfor %}
{% endmacro %}
