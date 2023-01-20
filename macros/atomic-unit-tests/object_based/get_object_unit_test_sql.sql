{% macro get_object_unit_test_sql(model, input_mapping, input_parameters, test_case_name) %}
    {% set ns=namespace(
        test_sql="(select 1) raw_sql",
        rendered_keys={},
        graph_model=none,
        preferred_language="sql",
        return_type="varchar",
        materialized_type="unknown",
        sdk_version="",
        import_Path="",
        packages="",
        handler_name="",
        imports="",
        target_path="",
        runtime_version="",
        view_data=""
    ) %}
    {% if input_mapping is not none %}
        {% for k in input_mapping.keys() %}
            {# doing this outside the execute block allows dbt to infer the proper dependencies #}
            {% do ns.rendered_keys.update({k: "{{ " + k + " }}" }) %}
        {% endfor %}
    {% endif %}
    
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
        {% set ns.test_sql = ns.graph_model.raw_sql %}
        {% set ns.preferred_language = ns.graph_model.config.get("preferred_language") %}
        {% set ns.return_type = ns.graph_model.config.get("return_type") %} 
        {% set ns.materialized_type = ns.graph_model.config.get("materialized") %} 

        {% if input_mapping is not none %}
            {% for k,v in input_mapping.items() %}
                {# render the original sql and replacement key before replacing because v is already rendered when it is passed to this test #}
                {% set ns.test_sql = ns.test_sql|replace(ns.rendered_keys[k], v) %}
            {% endfor %}
        {% endif %}
        {% set ns.test_sql = render(ns.test_sql) %}

        {% if input_parameters is not none %}
            {% for k,v in input_parameters.items() %}
                {# render the original sql and replacement key before replacing because v is already rendered when it is passed to this test #}
                {% if ns.materialized_type == "stored_procedure" %}
                    {% set ns.test_sql = render(ns.test_sql)|replace(":" ~ k, v) %}
                {% elif ns.materialized_type == "user_defined_function" %}
                    {% set ns.test_sql = render(ns.test_sql)|replace(k, v) %}
                {% endif %}
            {% endfor %}
        {% endif %}
        
        {% set target_relation = api.Relation.create( identifier=test_case_name, schema="unit_tests", database=database) %}
        {% set mock_model_relation = "unit_tests." + test_case_name %}

        {% if ns.materialized_type == "stored_procedure" %}
            {% set ns.view_data = dbt_dataengineers_utils.get_stored_procedure_unit_test_sql(ns, target_relation, mock_model_relation) %}

        {% elif ns.materialized_type == "user_defined_function" %}
            {% set ns.view_data = dbt_dataengineers_utils.get_user_defined_function_unit_test_sql(ns, target_relation, mock_model_relation) %}
        {% endif%}

    {% endif %}
    {{ ns.view_data }}
{% endmacro %}
