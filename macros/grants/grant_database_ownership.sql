{% macro grant_database_ownership(rolename) %}
   {% if flags.WHICH in ['run', 'run-operation'] %}
      {% do log("Adding Database Ownership rights on " + target.database  + " for " + rolename, info=True) %}
      grant ownership on database {{ target.database }} to role {{ rolename }} revoke current grants;
   {% endif %}
{% endmacro %}
