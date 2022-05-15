{% macro grant_schema_read_access(schemas, rolename, include_future_grants) %}
{% for current in schemas %}
    {% do log("Adding Read Access on " + current + " for " + rolename , info=True) %}
    GRANT USAGE ON SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON ALL VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON ALL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON ALL EXTERNAL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};

    {% if include_future_grants %}
    GRANT SELECT ON FUTURE VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON FUTURE MATERIALIZED VIEWS IN SCHEMA {{ current }} TO ROLE {{ rolename }};
    GRANT SELECT ON FUTURE TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};    
    GRANT SELECT ON FUTURE EXTERNAL TABLES IN SCHEMA {{ current }} TO ROLE {{ rolename }};    
    {% endif %}
{% endfor %}
{% endmacro %}
