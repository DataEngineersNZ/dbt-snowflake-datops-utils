{%- macro create_fileformat_stmt_fromfile(relation, sql) -%}

    {{ log("Creating fileformat " ~ relation) }}
CREATE OR REPLACE FILE FORMAT {{ relation.include(database=(not temporary), schema=(not temporary)) }}
    {{ sql }}
    ;

{%- endmacro -%}

