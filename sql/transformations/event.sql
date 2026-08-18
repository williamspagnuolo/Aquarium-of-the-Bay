MERGE `rocket_rez_data.event` AS tgt
USING (
  -- 1) Flatten raw JSON; exclude rows where ALL schedule fields are NULL
  WITH flattened AS (
    SELECT
      li.event.id                                    AS event_id,
      li.event.schedule.id                           AS schedule_id,
      li.event.type                                  AS event_type,
      li.event.name                                  AS event_name,
      CAST(li.event.schedule.date      AS DATE)      AS event_date,
      CAST(li.event.schedule.startTime AS TIMESTAMP) AS event_start,
      CAST(li.event.schedule.endTime   AS TIMESTAMP) AS event_end,
      r.id                                           AS order_id
    FROM `rocket_rez_data.raw_data` AS r
    LEFT JOIN UNNEST(IFNULL(r.lineItems, [])) AS li
    WHERE NOT (
      li.event.schedule.id        IS NULL AND
      li.event.schedule.date      IS NULL AND
      li.event.schedule.startTime IS NULL AND
      li.event.schedule.endTime   IS NULL
    )
  ),

  -- 2) Build schedule-composite key (sched_key)
  with_sched_key AS (
    SELECT
      *,
      CONCAT(
        'SCHED:', IFNULL(CAST(schedule_id AS STRING),'MISSING'), '|',
        IFNULL(CAST(event_date  AS STRING),'MISSING'), '|',
        IFNULL(CAST(event_start AS STRING),'MISSING'), '|'
      ) AS sched_key
    FROM flattened
  ),

  -- 3) Schedules where multiple distinct event_ids appear
  conflicting_sched AS (
    SELECT
      sched_key,
      COUNT(DISTINCT event_id) AS distinct_event_ids
    FROM with_sched_key
    GROUP BY sched_key
    HAVING COUNT(DISTINCT event_id) > 1
  ),

  -- 4) event_ids that are reused across >1 schedule (never use event_id to dedup those)
  reused_event_ids AS (
    SELECT event_id
    FROM with_sched_key
    WHERE event_id IS NOT NULL
    GROUP BY event_id
    HAVING COUNT(DISTINCT sched_key) > 1
  ),

  -- 5) Choose dedup key: use sched_key when conflicting OR reused id; else prefer event_id
  keyed AS (
    SELECT
      w.*,
      CASE
        WHEN c.sched_key IS NOT NULL
          OR re.event_id IS NOT NULL
        THEN w.sched_key
        ELSE COALESCE(CAST(w.event_id AS STRING), w.sched_key)
      END AS dedup_key
    FROM with_sched_key AS w
    LEFT JOIN conflicting_sched AS c ON w.sched_key = c.sched_key
    LEFT JOIN reused_event_ids  AS re ON w.event_id  = re.event_id
  ),

  -- 6) Rank event_id candidates per dedup group (most frequent wins; ties → smallest id)
  id_rank AS (
    SELECT
      dedup_key,
      event_id,
      COUNT(*) AS cnt,
      ROW_NUMBER() OVER (
        PARTITION BY dedup_key
        ORDER BY COUNT(*) DESC, event_id
      ) AS rn
    FROM keyed
    GROUP BY dedup_key, event_id
  ),

  -- 7) Pick canonical event_id
  chosen_id AS (
    SELECT dedup_key, event_id AS canonical_event_id
    FROM id_rank
    WHERE rn = 1
  ),

  -- 8) Collapse to one row per dedup_key (one real event)
  collapsed AS (
    SELECT
      k.dedup_key,
      ANY_VALUE(k.event_type)   AS event_type,
      ANY_VALUE(k.event_name)   AS event_name,
      ANY_VALUE(k.event_date)   AS event_date,
      ANY_VALUE(k.event_start)  AS event_start,
      MAX(k.event_end)          AS event_end,
      ANY_VALUE(k.schedule_id)  AS schedule_id,
      ANY_VALUE(k.order_id)     AS order_id
    FROM keyed AS k
    GROUP BY k.dedup_key
  ),

  -- 9) Final rows to upsert
  final_rows AS (
    SELECT
      GENERATE_UUID()            AS event_surrogate_key,
      c.canonical_event_id       AS event_id,
      x.event_type,
      x.event_name,
      x.event_date,
      x.event_start,
      x.event_end,
      x.schedule_id,
      x.order_id
    FROM collapsed AS x
    LEFT JOIN chosen_id AS c
      ON x.dedup_key = c.dedup_key
  )

  SELECT * FROM final_rows
) AS src
-- Natural identity (grain) for events:
ON  tgt.schedule_id IS NOT DISTINCT FROM src.schedule_id
AND tgt.event_date  IS NOT DISTINCT FROM src.event_date
AND tgt.event_start IS NOT DISTINCT FROM src.event_start

-- Insert missing events
WHEN NOT MATCHED THEN
  INSERT (
    event_surrogate_key,
    event_id,
    event_type,
    event_name,
    event_date,
    event_start,
    event_end,
    schedule_id,
    order_id
  )
  VALUES (
    src.event_surrogate_key,
    src.event_id,
    src.event_type,
    src.event_name,
    src.event_date,
    src.event_start,
    src.event_end,
    src.schedule_id,
    src.order_id
  )

-- Update when canonical attributes change (including event_end)
WHEN MATCHED AND (
    tgt.event_id   IS DISTINCT FROM src.event_id   OR
    tgt.event_type IS DISTINCT FROM src.event_type OR
    tgt.event_name IS DISTINCT FROM src.event_name OR
    tgt.order_id   IS DISTINCT FROM src.order_id   OR
    tgt.event_end  IS DISTINCT FROM src.event_end
)
THEN UPDATE SET
  tgt.event_id   = src.event_id,
  tgt.event_type = src.event_type,
  tgt.event_name = src.event_name,
  tgt.order_id   = src.order_id,
  tgt.event_end  = src.event_end;


ASSERT (
  SELECT COUNT(*)
  FROM (
    SELECT schedule_id, event_date, event_start
    FROM `rocket_rez_data.event`
    GROUP BY 1,2,3
    HAVING COUNT(*) > 1
  )
) = 0 AS 'Duplicate events at (schedule_id, event_date, event_start) detected.';