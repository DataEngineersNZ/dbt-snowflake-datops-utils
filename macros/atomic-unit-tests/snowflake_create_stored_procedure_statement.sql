{%- macro snowflake_create_stored_procedure_statement(relation, return_type, sql) -%}

    {{ log("Creating Stored Procedure " ~ relation) }}   
CREATE OR REPLACE PROCEDURE {{ relation.include(database=(not temporary), schema=(not temporary)) }}()
returns {{ return_type }}
language sql
AS
$$
    {{ sql }}
$$
;

{%- endmacro -%}