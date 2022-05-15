{% macro grant_database_usage_access(rolename) %}
{% do log("Adding Database Usage rights on " + target.database  + " for " + rolename, info=True) %}
GRANT USAGE ON DATABASE {{ target.database }} TO ROLE {{ rolename }};
{% endmacro %}
