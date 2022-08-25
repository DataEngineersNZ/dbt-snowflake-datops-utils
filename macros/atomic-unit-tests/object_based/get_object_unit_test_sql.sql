{% macro get_object_unit_test_sql(model, input_mapping, input_parameters, test_case_name) %}
    {% set ns=namespace(
        test_sql="(select 1) raw_sql",
        rendered_keys={},
        graph_model=none,
        preferred_language="sql",
        return_type="varchar",
        materialized_type="stored_procedure",
        sdk_version="",
        import_Path="",
        packages="",
        handler_name="",
        imports="",
        target_path="",
        runtime_version=""
    ) %}
    {% if input_mapping is not none %}
        {% for k in input_mapping.keys() %}
            {# doing this outside the execute block allows dbt to infer the proper dependencies #}
            {% do ns.rendered_keys.update({k: render("{{ " + k + " }}")}) %}
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
                {% set ns.test_sql = render(ns.test_sql)|replace(ns.rendered_keys[k], v) %}
            {% endfor %}
        {% endif %}

        {% if input_parameters is not none %}
            {% for k,v in input_parameters.items() %}
                {# render the original sql and replacement key before replacing because v is already rendered when it is passed to this test #}
                {% if ns.materialized_type == "stored_procedure" %}
                    {% set ns.test_sql = render(ns.test_sql)|replace(":" ~ k, v) %}
                {% else %}
                    {% set ns.test_sql = render(ns.test_sql)|replace(k, v) %}
                {% endif %}
            {% endfor %}
        {% endif %}


        {% set target_relation = api.Relation.create( identifier=test_case_name, schema="unit_tests", database=database) %}
        {% set mock_model_relation = "unit_tests." + test_case_name %}

        {% if ns.materialized_type == "stored_procedure" %}
            {% do dbt_dataengineers_utils._create_mock_stored_procedure(target_relation, ns.preferred_language, ns.return_type, ns.test_sql) %}
            {% set view_data = "(" ~ dbt_dataengineers_utils.create_return_view(mock_model_relation) ~ ")" %}
        {% else %}
            {% set ns.sdk_version = ns.graph_model.config.get("sdk_version") %}
            {% set ns.import_Path = ns.graph_model.config.get("import_Path") %}
            {% set ns.packages = ns.graph_model.config.get("packages") %}
            {% set ns.handler_name = ns.graph_model.config.get("handler_name") %}
            {% set ns.imports = ns.graph_model.config.get("imports") %}
            {% set ns.target_path = ns.graph_model.config.get("target_path") %}
            {% set ns.runtime_version = ns.graph_model.config.get("runtime_version") %}

            {% do dbt_dataengineers_utils._create_mock_user_defined_function(target_relation, ns.preferred_language, ns.return_type, ns.sdk_version, ns.import_Path, ns.packages, ns.handler_name, ns.imports, ns.target_path, ns.runtime_version, ns.test_sql) %}    
            {% if ns.return_type.startswith("table") %}
                {% set view_data = "( SELECT * FROM table(" ~ mock_model_relation ~ "()))" %}
            {% else %}
                {% set view_data = "( SELECT " ~ mock_model_relation ~ "() AS result)" %}
            {% endif %}
        {% endif%}

    {% endif %}
    {{ view_data }}
{% endmacro %}


{% macro _create_mock_stored_procedure(target_relation, preferred_language, return_type, test_sql) %}
    {{ return(adapter.dispatch('_create_mock_stored_procedure', 'dbt_dataengineers_utils')(target_relation, preferred_language, return_type, test_sql)) }}
{% endmacro %}

{% macro default___create_mock_stored_procedure(target_relation, preferred_language, return_type, test_sql) %}
    {% do run_query(snowflake_create_stored_procedure_statement(target_relation, preferred_language, return_type, test_sql)) %}
{% endmacro %}


{% macro _create_mock_user_defined_function(target_relation, preferred_language, return_type, sdk_version, import_Path, packages, handler_name, imports, target_path,runtime_version, test_sql) %}
    {{ return(adapter.dispatch('_create_mock_user_defined_function', 'dbt_dataengineers_utils')(target_relation, preferred_language, return_type, sdk_version, import_Path, packages, handler_name, imports, target_path,runtime_version, test_sql)) }}
{% endmacro %}

{% macro default___create_mock_user_defined_function(target_relation, preferred_language, return_type, sdk_version, import_Path, packages, handler_name, imports, target_path,runtime_version, test_sql) %}
    {% do run_query(snowflake_create_user_defined_functions_statement(target_relation, preferred_language, return_type, sdk_version, import_Path, packages, handler_name, imports, target_path,runtime_version, test_sql)) %}
{% endmacro %}
