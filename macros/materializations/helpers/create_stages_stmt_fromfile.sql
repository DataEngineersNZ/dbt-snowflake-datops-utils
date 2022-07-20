{%- macro create_stages_stmt_fromfile(relation, sql) -%}

    {{ log("Creating stages " ~ relation) }}
CREATE OR REPLACE STAGE {{ relation.include(database=(not temporary), schema=(not temporary)) }}
    {{ sql }}
    ;

{%- endmacro -%}