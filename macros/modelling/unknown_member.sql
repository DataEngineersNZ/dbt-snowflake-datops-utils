{% macro unknown_member(model_name) %}
    {%- if execute -%}
        {% if flags.WHICH in ('run', 'test') -%}
            {%- set column_types = [] -%}
            {%- set column_names = [] -%}
            {%- for node in graph.nodes.values() -%}
                {%- if node.name == model_name -%}
                    {%- for column, properties in node.columns.items() -%}
                        {%- do column_types.append(properties.get('type')) -%}
                        {%- do column_names.append(properties.get('name')) -%}
                    {%- endfor -%}
                {%- endif -%}
            {%- endfor -%}
    {%- set line_start = "" -%}
    select
        {%- for i in range(0, column_names|length) -%}
            {%- if not loop.last -%}
                {%- set line_end = "," -%}
            {%- else -%}
                {%- set line_end = "" -%}
            {%- endif -%}
            {%- if (column_names[i].endswith('_key') or column_names[i].endswith('_pk')) %}
        {{ var("unknown_member_surrogate_key") }} as {{ column_names[0] }}{{ line_end }}
            {%- elif column_names[i] == 'effective_from' or column_types[i]|upper in ['DATE'] %}
        to_timestamp_ltz('1900-01-01') as {{ column_names[i] }}{{ line_end }}
            {%- elif column_names[i] == 'effective_to' %}
        to_timestamp_ltz('2999-12-31 23:59:59') as effective_to{{ line_end }}
            {%- elif column_names[i] == 'is_current' %}
        true as is_current{{ line_end }}
            {%- elif column_names[i] == 'is_deleted' %}
        false as is_deleted{{ line_end }}
            {%- elif 'finish' in column_names[i] and column_names[i].endswith('_date') and column_types[i]|upper in ['NUMBER', 'INT', 'INTEGER']%}
        29991231 as {{ column_names[i] }}{{ line_end }}
            {%- elif column_names[i].endswith('_date') and column_types[i]|upper in ['NUMBER', 'INT', 'INTEGER']%}
        19000101 as {{ column_names[i] }}{{ line_end }}
            {%- elif column_names[i].endswith('_date_fk') and column_types[i]|upper in ['NUMBER', 'INT', 'INTEGER']%}
        19000101 as {{ column_names[i] }}{{ line_end }}
            {%- elif column_types[i]|upper in ['NUMBER','INT','DECIMAL']%}
        -1 as {{ column_names[i] }}{{ line_end }}
            {%- elif column_types[i]|upper in ['BOOLEAN']%}
        true as {{ column_names[i] }}{{ line_end }}
            {%- else %}
        'Unknown' as {{ column_names[i] }}{{ line_end }}
            {%- endif %}
        {%- endfor %}
    union all
	    {%- endif -%}
    {%- endif -%}
{%- endmacro %}