-- Test all checks macros with known inputs
select
    -- get_populated_array: first non-empty array wins
    {{ dbt_dataengineers_utils.get_populated_array("ARRAY_CONSTRUCT('a','b')", "ARRAY_CONSTRUCT('c')") }}
        as populated_array_with_values,

    {{ dbt_dataengineers_utils.get_populated_array("ARRAY_CONSTRUCT()", "ARRAY_CONSTRUCT('fallback')") }}
        as populated_array_fallback,

    -- get_populated_array_value_as_string: join non-empty array
    {{ dbt_dataengineers_utils.get_populated_array_value_as_string("ARRAY_CONSTRUCT('x','y','z')", "ARRAY_CONSTRUCT('f')") }}
        as array_value_as_string,

    {{ dbt_dataengineers_utils.get_populated_array_value_as_string("ARRAY_CONSTRUCT()", "ARRAY_CONSTRUCT('fallback')") }}
        as array_value_as_string_fallback,

    -- get_populated_array_value_or_string_as_string: array or string fallback
    {{ dbt_dataengineers_utils.get_populated_array_value_or_string_as_string("ARRAY_CONSTRUCT('a','b')", "'fallback_str'") }}
        as array_or_string_with_array,

    {{ dbt_dataengineers_utils.get_populated_array_value_or_string_as_string("ARRAY_CONSTRUCT()", "'fallback_str'") }}
        as array_or_string_fallback,

    -- get_populated_numeric_value: first non-zero numeric
    {{ dbt_dataengineers_utils.get_populated_numeric_value("10", "42") }}
        as numeric_value_populated,

    {{ dbt_dataengineers_utils.get_populated_numeric_value("0", "42") }}
        as numeric_value_fallback,

    {{ dbt_dataengineers_utils.get_populated_numeric_value("NULL", "99") }}
        as numeric_value_null,

    -- get_populated_string_value: first non-empty string
    {{ dbt_dataengineers_utils.get_populated_string_value("'hello'", "'world'") }}
        as string_value_populated,

    {{ dbt_dataengineers_utils.get_populated_string_value("''", "'fallback'") }}
        as string_value_fallback,

    {{ dbt_dataengineers_utils.get_populated_string_value("NULL", "'fallback'") }}
        as string_value_null
