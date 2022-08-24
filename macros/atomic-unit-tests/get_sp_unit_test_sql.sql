{% macro get_sp_unit_test_sql(model, input_mapping, input_parameters, test_case_name) %}
    {% set ns=namespace(
        test_sql="(select 1) raw_sql",
        rendered_keys={},
        graph_model=none,
        preferred_language="sql",
        return_type="varchar"
    ) %}

    {% for k in input_mapping.keys() %}
        {# doing this outside the execute block allows dbt to infer the proper dependencies #}
        {% do ns.rendered_keys.update({k: render("{{ " + k + " }}")}) %}
    {% endfor %}

    {% if execute %}
        {# inside an execute block because graph nodes aren't well-defined during parsing #}
        {% set ns.graph_model = graph.nodes.get("model." + project_name + "." + model.name) %}
        {# if the model uses an alias, the above call was unsuccessful, so loop through the graph to grab it by the alias instead #}
        {% if ns.graph_model is none %}
            {% for node in graph.nodes.values() %}
                {% if node.alias == model.name and node.schema == model.schema %}
                    {% set ns.graph_model = node %}
                {% endif %}
            {% endfor %}
        {% endif %}
        {% set ns.test_sql = ns.graph_model.raw_sql %}
        {% set ns.preferred_language = ns.graph_model.config.get("preferred_language") %}
        {% set ns.return_type = ns.graph_model.config.get("return_type") %} 

        {% if input_mapping is not none %}
            {% for k,v in input_mapping.items() %}
                {# render the original sql and replacement key before replacing because v is already rendered when it is passed to this test #}
                {% set ns.test_sql = render(ns.test_sql)|replace(ns.rendered_keys[k], v) %}
            {% endfor %}
        {% endif %}

        {% if input_parameters is not none %}
            {% for k,v in input_parameters.items() %}
                {# render the original sql and replacement key before replacing because v is already rendered when it is passed to this test #}
                {% set ns.test_sql = render(ns.test_sql)|replace(":" ~ k, v) %}
            {% endfor %}
        {% endif %}

        {% set target_relation = api.Relation.create( identifier=test_case_name, schema="unit_tests", database=database) %}
        {% set mock_model_relation = "unit_tests." + test_case_name %}

        {% do dbt_dataengineers_utils._create_mock_stored_procedure(target_relation, ns.preferred_language, ns.return_type, ns.test_sql) %}
        
        {% set view_data = "(" ~ dbt_dataengineers_utils.create_return_view(mock_model_relation) ~ ")" %}

    {% endif %}
    {{ view_data }}
{% endmacro %}

{%- macro create_return_view(mock_model_relation) %}
        {% set execute_sql = "CALL " ~ mock_model_relation ~ "();" %}
        {% set results = run_query(execute_sql) %}


        {% set view_data = namespace(value="") %}
        
        {% for record in results %}
            {% set view_data.value = view_data.value ~ create_select_row(results.columns, record.values()) %}
            {% if not loop.last %}
                {% set view_data.value = view_data.value ~ "
UNION ALL
" %}
            {% endif %}
        {% endfor %}
    {{ return(view_data.value) }}
{% endmacro -%}

{% macro get_column_data(data) %}
    {% if data is number  %}
        {{ return(data) }}
    {% else %}
        {{ return("'" ~ data ~ "'") }}
    {% endif %}
  
{% endmacro %}

{% macro create_select_row(columns, values) %}
    {% set stm = namespace(value="SELECT ") %}
    {% for column in columns %}
        {%- set stm.value = stm.value ~ get_column_data(values[loop.index -1]) ~ " AS " ~ column.name -%}
        {% if not loop.last %}
            {%- set stm.value = stm.value ~ ", " -%}
        {% endif %}
    {% endfor %}
    {{ return(stm.value) }}
{% endmacro %}


{% macro _create_mock_stored_procedure(target_relation, preferred_language, return_type, test_sql) %}
    {{ return(adapter.dispatch('_create_mock_stored_procedure', 'dbt_dataengineers_utils')(target_relation, preferred_language, return_type, test_sql)) }}
{% endmacro %}

{% macro default___create_mock_stored_procedure(target_relation, preferred_language, return_type, test_sql) %}
    {% do run_query(snowflake_create_stored_procedure_statement(target_relation, preferred_language, return_type, test_sql)) %}
{% endmacro %}
