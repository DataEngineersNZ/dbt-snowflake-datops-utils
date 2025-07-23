{% macro grant_database_ownership(role_name) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% if execute %}
			{% do log("Verifying Ownership rights on " ~ target.database ~ " for " ~ role_name, info=True) %}
		 	{% set results = run_query('show grants on database ' ~ target.database | lower ~ ' ->> select * from $1 where "privilege" = ' ~ "'OWNERSHIP'" ~ ' and "grantee_name" = ' ~ "'" ~ role_name|upper ~ '";') %}
			{% if results | length == 0 %}
				{% do log("Modifiying Database Ownership rights on " ~ target.database ~ " to " ~ role_name, info=True) %}
				{% set query %}
				grant ownership on database {{ target.database }} to role {{ role_name }} revoke current grants;
				{% endset %}
				{% do run_query(query) %}
			{% endif %}
		{% endif %}
    {% endif %}
{% endmacro %}