-- Test date_key, time_key, datetime_to_date_dim, datetime_to_time_dim
select
    -- date_key: date -> YYYYMMDD string
    {{ dbt_dataengineers_utils.date_key("'2024-03-15'::date") }}
        as date_key_result,

    -- time_key: timestamp -> HHMI string
    {{ dbt_dataengineers_utils.time_key("'2024-03-15 14:30:00'::timestamp") }}
        as time_key_result,

    -- datetime_to_date_dim: timestamp -> YYYYMMDD
    {{ dbt_dataengineers_utils.datetime_to_date_dim("'2024-03-15 14:30:00'::timestamp") }}
        as datetime_to_date_result,

    -- datetime_to_time_dim: timestamp -> HHMI
    {{ dbt_dataengineers_utils.datetime_to_time_dim("'2024-03-15 14:30:00'::timestamp") }}
        as datetime_to_time_result,

    -- datetime_from_dim: reconstruct timestamp from date/time keys
    {{ dbt_dataengineers_utils.datetime_from_dim("20240315", "1430") }}
        as datetime_from_dim_result,

    -- dimension_id: concatenate fields
    {{ dbt_dataengineers_utils.dimension_id(["'ABC'", "'123'"]) }}
        as dimension_id_result,

    -- generate_surrogate_key: MD5 hash
    {{ dbt_dataengineers_utils.generate_surrogate_key(["'ABC'", "'123'"]) }}
        as surrogate_key_result,

    -- generate_surrogate_key with NULL input
    {{ dbt_dataengineers_utils.generate_surrogate_key(["'ABC'", "NULL"]) }}
        as surrogate_key_with_null
