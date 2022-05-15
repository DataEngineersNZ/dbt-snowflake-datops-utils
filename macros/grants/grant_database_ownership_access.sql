{% macro grant_database_ownership_access(rolename) %}
{% do log("Adding Database Ownership rights on " + target.database  + " for " + rolename, info=True) %}
GRANT OWNERSHIP ON DATABASE {{ target.database }} TO ROLE {{ rolename }} REVOKE CURRENT GRANTS;
{% endmacro %}
