CREATE TEMP TABLE validation_results AS(

WITH
-- ===============================================================
-- 0. COMMON CTEs
-- ===============================================================
raw_events AS (
SELECT DISTINCT
    li.event.schedule.id                           AS schedule_id,
    CAST(li.event.schedule.date AS DATE)           AS event_date,
    CAST(li.event.schedule.startTime AS TIMESTAMP) AS event_start,
    CAST(li.event.schedule.endTime   AS TIMESTAMP) AS event_end,
    li.event.id                                    AS raw_event_id
FROM `rocket_rez_data.raw_data` r
LEFT JOIN UNNEST(IFNULL(r.lineItems, [])) li
WHERE NOT (
    li.event.schedule.id        IS NULL
    AND li.event.schedule.date      IS NULL
    AND li.event.schedule.startTime IS NULL
    AND li.event.schedule.endTime   IS NULL
)
),

event_table AS (
SELECT * FROM `rocket_rez_data.event`
),

-- RAW tuples at canonical grain (event_end NOT part of identity)
sched_tuple_raw AS (
SELECT DISTINCT
    schedule_id,
    event_date,
    event_start
FROM raw_events
),

sched_tuple_event AS (
SELECT DISTINCT
    schedule_id,
    event_date,
    event_start
FROM event_table
),

-- RAW event_ids reused across multiple schedules (guard test)
event_ids_reused AS (
SELECT raw_event_id AS event_id
FROM raw_events
WHERE raw_event_id IS NOT NULL
GROUP BY raw_event_id
HAVING COUNT(
    DISTINCT CONCAT(
    IFNULL(CAST(schedule_id AS STRING),'NULL'), '|',
    IFNULL(CAST(event_date  AS STRING),'NULL'), '|',
    IFNULL(CAST(event_start AS STRING),'NULL')
    )
) > 1
),

-- Canonical RAW event per schedule = MAX(event_end)
canonical_raw AS (
SELECT
    schedule_id,
    event_date,
    event_start,
    event_end,
    raw_event_id
FROM (
    SELECT
    schedule_id,
    event_date,
    event_start,
    event_end,
    raw_event_id,
    ROW_NUMBER() OVER (
        PARTITION BY schedule_id, event_date, event_start
        ORDER BY event_end DESC
    ) AS rn
    FROM raw_events
)
WHERE rn = 1
)

-- ===============================================================
-- ALL TESTS BELOW HAVE SAME OUTPUT SHAPE
-- ===============================================================

-- ---------------------------------------------------------------
-- 1. Duplicate events at canonical grain
-- ---------------------------------------------------------------
SELECT
'Error' AS severity,
'1. DUPLICATE EVENTS (should be 0)' AS test_name,
TO_JSON_STRING(t) AS result_json
FROM (
SELECT
    schedule_id,
    event_date,
    event_start,
    COUNT(*) AS cnt
FROM event_table
GROUP BY 1,2,3
HAVING COUNT(*) > 1
) t


UNION ALL

-- ---------------------------------------------------------------
-- 2. RAW → EVENT completeness (canonical grain)
-- ---------------------------------------------------------------
SELECT
'Error' AS severity,
'2. RAW → EVENT MISSING (should be 0)',
TO_JSON_STRING(t)
FROM (
SELECT r.*
FROM sched_tuple_raw r
LEFT JOIN sched_tuple_event e
    USING (schedule_id, event_date, event_start)
WHERE e.schedule_id IS NULL
) t


UNION ALL

-- ---------------------------------------------------------------
-- 4. Attribute inconsistencies (end-time allowed to vary)
-- ---------------------------------------------------------------
SELECT
'Error' AS severity,
'4. ATTRIBUTE INCONSISTENCIES (should be 0)',
TO_JSON_STRING(t)
FROM (
SELECT
    schedule_id,
    COUNT(DISTINCT event_name)  AS names,
    COUNT(DISTINCT event_type)  AS types,
    COUNT(DISTINCT event_date)  AS dates,
    COUNT(DISTINCT event_start) AS starts
FROM event_table
GROUP BY schedule_id, event_date, event_start
HAVING
    names  > 1 OR
    types  > 1 OR
    dates  > 1 OR
    starts > 1
) t

UNION ALL

-- ---------------------------------------------------------------
-- 5. Surrogate key uniqueness summary
-- ---------------------------------------------------------------
SELECT
'INFO' AS severity,
'5. SURROGATE KEY UNIQUENESS',
TO_JSON_STRING(t)
FROM (
SELECT
    (SELECT COUNT(*) FROM event_table)                      AS total_rows,
    (SELECT COUNT(DISTINCT event_surrogate_key)
    FROM event_table)                                     AS distinct_keys
) t

UNION ALL

-- ---------------------------------------------------------------
-- 6. Null identity rows
-- ---------------------------------------------------------------
SELECT
'Error' AS severity,
'6. NULL-IDENTITY ROWS (should be 0)',
TO_JSON_STRING(t)
FROM (
SELECT *
FROM event_table
WHERE schedule_id IS NULL
    AND event_date  IS NULL
    AND event_start IS NULL
) t

UNION ALL

-- ---------------------------------------------------------------
-- 7. Guard: reused event_ids must not merge schedules
-- ---------------------------------------------------------------
SELECT
'WARN' AS severity,
'7. OPTION A GUARD — reused event_ids must not merge schedules',
TO_JSON_STRING(t)
FROM (
SELECT
    e.event_id,
    COUNT(
    DISTINCT CONCAT(
        IFNULL(CAST(e.schedule_id AS STRING),'NULL'), '|',
        IFNULL(CAST(e.event_date  AS STRING),'NULL'), '|',
        IFNULL(CAST(e.event_start AS STRING),'NULL')
    )
    ) AS distinct_schedules_in_event_table
FROM event_table e
WHERE e.event_id IN (SELECT event_id FROM event_ids_reused)
GROUP BY e.event_id
HAVING COUNT(
    DISTINCT CONCAT(
    IFNULL(CAST(e.schedule_id AS STRING),'NULL'), '|',
    IFNULL(CAST(e.event_date  AS STRING),'NULL'), '|',
    IFNULL(CAST(e.event_start AS STRING),'NULL')
    )
) = 1   -- WRONG: reused ID collapsed multiple schedules!
) t);

INSERT INTO `rocket_rez_data.audit_log`
(
    audit_timestamp,
    table_name,
    severity,
    test_name,
    result_json
)
SELECT
    CURRENT_TIMESTAMP(),
    'event',
    severity,
    test_name,
    result_json
FROM validation_results;

ASSERT (
    SELECT COUNT(*)
    FROM validation_results
    WHERE severity = 'ERROR'
) = 0
AS 'Event validation failed.';