{% macro drop_object(object_type, database, items_to_drop, dry_run=true) %}
    {% if items_to_drop | length > 0 %}
        {% for item in items_to_drop %}
            {%- set drop_query -%}
                DROP {{ object_type }} IF EXISTS {{ database }}.{{ item }}
            {%- endset -%}
            {{ log("dry-run: " ~ dry_run, info=true) }}
            {% if dry_run %}
                {{ log(drop_query, info=true) }}
            {% else %}
                {{ log("RUNNING : " ~ drop_query, info=true) }}
                {{ run_query(drop_query) }}
            {% endif %}
        {% endfor %}
    {% else %}
        {{ log("No " ~ object_type | lower ~ "s to drop", info=True) }}
    {% endif %}

{% endmacro %}