{% macro create_internal_share(share_name, reference_databases, environments) %}
    {% if flags.WHICH in ['run', 'run-operation'] %}
        {% if execute %}
            {% if target.name in environments %}
                {% do log("Creating or Updating Share " ~ share_name, info=True) %}
                {# Create share if not exists #}
                {% set create_sql %}
                    create share if not exists {{ share_name }} secure_objects_only=false;
                {% endset %}
                {% do run_query(create_sql) %}

                {# Check if usage already granted on target database #}
                {% set grants_query %}
                    show grants on database {{ target.database }};
                {% endset %}
                {% set grants_result = run_query(grants_query) %}
                {% set has_usage = false %}
                {% if grants_result is not none %}
                    {% for row in grants_result %}
                        {% if row.privilege == 'USAGE' and row.grantee_name == share_name %}
                            {% set has_usage = true %}
                        {% endif %}
                    {% endfor %}
                {% endif %}
                {% if not has_usage %}
                    {% set usage_sql %}
                        grant usage on database {{ target.database }} to share {{ share_name }};
                    {% endset %}
                    {% do run_query(usage_sql) %}
                {% endif %}

                {# Grant reference_usage on reference databases if not already granted #}
                {% for reference_database in reference_databases %}
                    {% set ref_grants_query %}
                        show grants on database {{ reference_database }};
                    {% endset %}
                    {% set ref_grants_result = run_query(ref_grants_query) %}
                    {% set has_ref_usage = false %}
                    {% if ref_grants_result is not none %}
                        {% for row in ref_grants_result %}
                            {% if row.privilege == 'REFERENCE_USAGE' and row.grantee_name == share_name %}
                                {% set has_ref_usage = true %}
                            {% endif %}
                        {% endfor %}
                    {% endif %}
                    {% if not has_ref_usage %}
                        {% set ref_usage_sql %}
                            grant reference_usage on database {{ reference_database }} to share {{ share_name }};
                        {% endset %}
                        {% do run_query(ref_usage_sql) %}
                    {% endif %}
                {% endfor %}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}