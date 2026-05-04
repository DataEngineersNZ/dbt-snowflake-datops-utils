-- Assert: surrogate_key is deterministic (same inputs = same hash)
-- and different from the NULL variant
select * from {{ ref('test_modelling') }}
where surrogate_key_result is null
   or surrogate_key_with_null is null
   or surrogate_key_result = surrogate_key_with_null
