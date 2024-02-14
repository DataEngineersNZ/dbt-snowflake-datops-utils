{% macro grant_database_ownership_access(rolename) %}
{% do log("Adding Database Ownership rights on " + target.database  + " for " + rolename, info=True) %}
grant ownership on {{ target.database }} to role {{ rolename }} revoke current grants;
{% endmacro %}
