{%- macro snowflake_create_stored_procedure_statement(relation, ns) -%}

CREATE OR REPLACE PROCEDURE {{ relation.include(database=(not temporary), schema=(not temporary)) }}()
RETURNS {{ ns.return_type }}
LANGUAGE {{ ns.preferred_language }}
AS
$$
    {{ ns.test_sql }}
$$
;

{%- endmacro -%}
