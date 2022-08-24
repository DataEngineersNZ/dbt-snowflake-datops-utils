@@ -0,0 +1,13 @@
{%- macro snowflake_create_stored_procedure_statement(relation, preferred_language, return_type, sql) -%}

    {{ log("Creating Stored Procedure " ~ relation) }}   
CREATE OR REPLACE PROCEDURE {{ relation.include(database=(not temporary), schema=(not temporary)) }}()
RETURNS {{ return_type }}
LANGUAGE {{ preferred_language }}
AS
$$
    {{ sql }}
$$
;

{%- endmacro -%} 