{% macro get_model_unit_test_sql(model, input_mapping, test_case_name) %}
    {% set ns=namespace(
        test_sql="(select 1) raw_sql",
        rendered_keys={},
        graph_model=none
    ) %}

    {% for k in input_mapping.keys() %}
        {# doing this outside the execute block allows dbt to infer the proper dependencies #}
        {% do ns.rendered_keys.update({k: "{{ " + k + " }}" }) %}
    {% endfor %}

    {% if execute %}
        {# inside an execute block because graph nodes arent well-defined during parsing #}
        {% set ns.graph_model = graph.nodes.get("model." + project_name + "." + model.name) %}
        {# if the model uses an alias, the above call was unsuccessful, so loop through the graph to grab it by the alias instead #}
        {% if ns.graph_model is none %}
            {% for node in graph.nodes.values() %}
                {% if node.alias == model.name and node.schema == model.schema %}
                    {% set ns.graph_model = node %}
                {% endif %}
            {% endfor %}
        {% endif %}
        {% set ns.test_sql = ns.graph_model.raw_code %}

        {% if input_mapping is not none %}
            {% for k,v in input_mapping.items() %}
                {# render the original sql and replacement key before replacing because v is already rendered when it is passed to this test #}
                {% set ns.test_sql = ns.test_sql|replace(ns.rendered_keys[k], v) %}
            {% endfor %}
        {% endif %}
        {% set ns.test_sql = render(ns.test_sql) %}

        {% set mock_model_relation = "unit_tests." + test_case_name %}

        {% do dbt_dataengineers_utils._create_mock_table_or_view(mock_model_relation, ns.test_sql) %}
    {% endif %}


    {{ mock_model_relation }}
{% endmacro %}

{% macro _get_model_to_mock(model, suffix) %}
    {{ return(adapter.dispatch('_get_model_to_mock', 'dbt_dataengineers_utils')(model, suffix)) }}
{% endmacro %}

{% macro default___get_model_to_mock(model, suffix) %}
    {{ return(make_temp_relation(model.incorporate(type='table', suffix=suffix))) }}
{% endmacro %}

{% macro _create_mock_table_or_view(model, test_sql) %}
    {{ return(adapter.dispatch('_create_mock_table_or_view', 'dbt_dataengineers_utils')(model, test_sql)) }}
{% endmacro %}

{% macro default___create_mock_table_or_view(model, test_sql) %}
    {% do run_query(create_table_as(False, model, test_sql)) %}
{% endmacro %}
