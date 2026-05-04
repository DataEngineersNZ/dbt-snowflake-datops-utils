-- Test all parse macros
select
    -- to_date: parse string to date
    {{ dbt_dataengineers_utils.to_date("'20240315'", "YYYYMMDD") }}
        as to_date_result,

    -- num_to_date: numeric to date
    {{ dbt_dataengineers_utils.num_to_date("20240315") }}
        as num_to_date_result,

    -- num_to_date: invalid number returns NULL
    {{ dbt_dataengineers_utils.num_to_date("99999999") }}
        as num_to_date_invalid,

    -- string_to_num: comma-formatted string to number
    {{ dbt_dataengineers_utils.string_to_num("'1,234,567'") }}
        as string_to_num_result,

    -- null_to_empty_string: NULL -> ''
    {{ dbt_dataengineers_utils.null_to_empty_string("NULL") }}
        as null_to_empty_result,

    -- null_to_empty_string: non-NULL passthrough
    {{ dbt_dataengineers_utils.null_to_empty_string("'hello'") }}
        as null_to_empty_passthrough,

    -- first_day_of_month
    {{ dbt_dataengineers_utils.first_day_of_month("'2024'", "'03'", "MM") }}
        as first_day_result,

    -- last_day_of_month
    {{ dbt_dataengineers_utils.last_day_of_month("'2024'", "'02'", "MM") }}
        as last_day_result,

    -- last_day_of_month: non-leap year
    {{ dbt_dataengineers_utils.last_day_of_month("'2023'", "'02'", "MM") }}
        as last_day_non_leap,

    -- string_epoch_to_timestamp_ltz
    {{ dbt_dataengineers_utils.string_epoch_to_timestamp_ltz("'/Date(1710500000000+0000)/'") }}
        as epoch_ltz_result,

    -- string_epoch_to_timestamp_ntz
    {{ dbt_dataengineers_utils.string_epoch_to_timestamp_ntz("'/Date(1710500000000+0000)/'") }}
        as epoch_ntz_result
