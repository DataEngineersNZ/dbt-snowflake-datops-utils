{% macro set_column_tag_value(materlization, model_schema, model_name,column_name,tag_name,desired_tag_value, existing_tags_for_table) %}
    {% if tag_name.endswith('_type') %}
        {%set tag_name=tag_name|replace("_type", "_data") %}
    {% endif %}
    {%- set existing_tag_for_column = existing_tags|selectattr('0','equalto','COLUMN')|selectattr('1','equalto',table_name|upper)|selectattr('2','equalto',column_name|upper)|selectattr('3','equalto',tag_name|upper)|list -%}
    {% if existing_tag_for_column|length > 0 and existing_tag_for_column[0][4]==desired_tag_value %}
        {{ log(column_name + ' ==> tag ' + tag_name + ' already set to value '+ desired_tag_value + ' ............... [IGNORE]', info=True) }}
    {% elif existing_tag_for_column|length > 0 and desired_tag_value|lower=="none" %}
        {{ log("START removing tag " + tag_name + " from column '" + column_name|lower + "' for " + materlization|lower + " model " +  model_schema|lower + "." + model_name|lower + " ............... [RUN]", info=True) }}
        {%- call statement('unset_statement', fetch_result=True) -%}
            alter {{materlization}} {{model_schema|upper}}.{{model_name|upper}} modify column {{column_name}} unset tag {{ var("data_governance_database") }}.{{ var("tag_store") }}.{{tag_name|upper}}
        {%- endcall -%}
        {% set result = load_result('unset_statement')%}
        {% if result['response']|string == "SUCCESS 1" %}
            {{ log("OK removing tag " + tag_name + " from column '" + column_name|lower + "' for " + materlization|lower + " model " +  model_schema|lower + "." + model_name|lower + " ............... [" + result["response"]|string  + "]", info=True) }}
        {% else %}
            {{ log("ERROR removing tag " + tag_name + " from column '" + column_name|lower + "' for " + materlization|lower + " model " +  model_schema|lower + "." + model_name|lower + " ............... [" + result["response"]|string  + "]", info=True) }}
            {{ log(result.data, info=True) }}
        {% endif %}
    {% elif desired_tag_value|lower != "none" %}
        {% if  desired_tag_value != "none"%}
            {{ log("START setting tag " + tag_name + " on column '" + column_name|lower + "' to value' " + desired_tag_value + "' for " + materlization|lower + " model " +  model_schema|lower + "." + model_name|lower + " ............... [RUN]", info=True) }}
            {%- call statement('set_statement', fetch_result=True) -%}
                alter {{materlization}} {{model_schema|upper}}.{{model_name|upper}} modify column {{column_name}} set tag {{ var("data_governance_database") }}.{{ var("tag_store") }}.{{tag_name|upper}} = '{{desired_tag_value}}'
            {%- endcall -%}
            {% set result = load_result('set_statement')%}
            {% if result['response']|string == "SUCCESS 1" %}
                {{ log("OK setting tag " + tag_name + " on column '" + column_name|lower + "' to value' " + desired_tag_value + "' for " + materlization|lower + " model " +  model_schema|lower + "." + model_name|lower + " ............... [" + result["response"]|string  + "]", info=True) }}
            {% else %}
                {{ log("ERROR setting tag " + tag_name + " on column '" + column_name|lower + "' to value' " + desired_tag_value + "' for " + materlization|lower + " model " +  model_schema|lower + "." + model_name|lower + " ............... [" + result["response"]|string  + "]", info=True) }}
                {{ log(result.data, info=True) }}
            {% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}
