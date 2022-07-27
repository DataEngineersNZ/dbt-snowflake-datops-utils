{%- macro create_storedprocedure_stmt_fromfile(relation, preferred_language, parameters, return_type, sql) -%}

    {{ log("Creating Stored Procedure " ~ relation) }}   
CREATE OR REPLACE PROCEDURE {{ relation.include(database=(not temporary), schema=(not temporary)) }}({{ parameters }})
returns {{ return_type }}
language {{ preferred_language }}
AS
$$
    {{ sql }}
$$
;

{%- endmacro -%}