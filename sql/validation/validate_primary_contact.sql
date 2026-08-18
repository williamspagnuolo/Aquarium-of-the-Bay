-- ===============================================================
-- MASTER VALIDATION SCRIPT — json_test.primary_contact
-- Aligns with new rules:
--   • Grain: one row per ORDER (order_id)
--   • PK: contact_surrogate_key (UUID)
--   • primary_contact_id is metadata (may repeat)
--   • Unknown contacts are allowed (walk-up); flagged, not filtered
-- Output schema is uniform: (test_name STRING, result_json STRING)
-- ===============================================================

CREATE TEMP TABLE validation_results AS(

WITH
/* ---------------------------------------------------------------
   0) TABLE references
---------------------------------------------------------------- */
contacts AS (
  SELECT * FROM `rocket_rez_data.primary_contact`
),
orders_raw AS (  -- orders present in raw (each should have one contact row after load)
  SELECT DISTINCT r.id AS order_id
  FROM `rocket_rez_data.raw_data` r
),

/* ---------------------------------------------------------------
   1) Derived "unknown" flag from fields (no dependency on stored column)
      Unknown if ALL identity fields are empty/placeholder:
      email, first_name, last_name, phone
---------------------------------------------------------------- */
contacts_aug AS (
  SELECT
    c.*,
    -- normalized versions (defensive)
    NULLIF(LOWER(TRIM(email)), 'no email') AS email_norm,
    NULLIF(REGEXP_REPLACE(LOWER(TRIM(phone)), r'[^0-9x]', ''), '') AS phone_norm,
    TRIM(first_name) AS first_name_norm,
    TRIM(last_name)  AS last_name_norm,
    -- derived unknown-contact flag
    CASE
      WHEN (email IS NULL OR LOWER(TRIM(email)) = 'no email' OR TRIM(email) = '')
       AND (first_name IS NULL OR TRIM(first_name) = '')
       AND (last_name  IS NULL OR TRIM(last_name)  = '')
       AND (phone IS NULL OR REGEXP_REPLACE(LOWER(TRIM(phone)), r'[^0-9x]', '') = '')
      THEN TRUE ELSE FALSE
    END AS is_unknown_derived
  FROM contacts c
),

/* ---------------------------------------------------------------
   2) If you added a stored is_unknown_contact, validate consistency
---------------------------------------------------------------- */
unknown_mismatch AS (
  SELECT
    order_id, contact_surrogate_key, is_unknown_derived,
    /* If column doesn't exist, this expression will error.
       To run safely regardless of column presence, comment the next line
       and the "Test 5A" UNION at the bottom. */
    SAFE_CAST(NULLIF(CAST(c.is_unknown_contact AS STRING), '') AS BOOL) AS is_unknown_stored
  FROM contacts_aug c
  WHERE TRUE
),
unknown_mismatch_rows AS (
  SELECT *
  FROM unknown_mismatch
  WHERE is_unknown_stored IS NOT NULL
    AND is_unknown_stored IS DISTINCT FROM is_unknown_derived
),

/* ---------------------------------------------------------------
   3) Not-null overview (table-level)
---------------------------------------------------------------- */
null_overview AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNTIF(contact_surrogate_key IS NULL) AS null_contact_surrogate_key,
    COUNTIF(order_id IS NULL)              AS null_order_id,
    COUNTIF(email IS NULL OR LOWER(TRIM(email)) = 'no email' OR TRIM(email) = '') AS empty_email,
    COUNTIF(first_name IS NULL OR TRIM(first_name) = '')                           AS empty_first_name,
    COUNTIF(last_name  IS NULL OR TRIM(last_name)  = '')                           AS empty_last_name,
    COUNTIF(phone IS NULL OR REGEXP_REPLACE(LOWER(TRIM(phone)), r'[^0-9x]', '') = '') AS empty_phone
  FROM contacts
),

/* ---------------------------------------------------------------
   4) Duplicates by ORDER grain (should be 0)  ← new rule
---------------------------------------------------------------- */
dups_by_order AS (
  SELECT order_id, COUNT(*) AS cnt
  FROM contacts
  WHERE order_id IS NOT NULL
  GROUP BY order_id
  HAVING COUNT(*) > 1
),

/* ---------------------------------------------------------------
   5) Surrogate key uniqueness
---------------------------------------------------------------- */
sk_uniqueness AS (
  SELECT
    (SELECT COUNT(*) FROM contacts) AS total_rows,
    (SELECT COUNT(DISTINCT contact_surrogate_key) FROM contacts) AS distinct_surrogate_keys
),

/* ---------------------------------------------------------------
   6) Unknown contact summary (allowed; we just report rate)
---------------------------------------------------------------- */
unknown_summary AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNTIF(is_unknown_derived) AS unknown_rows,
    SAFE_DIVIDE(COUNTIF(is_unknown_derived), COUNT(*)) AS unknown_rate
  FROM contacts_aug
),

/* ---------------------------------------------------------------
   7) Basic format checks (post-load)
      These are informational now that you normalize on load.
---------------------------------------------------------------- */
bad_email_format AS (
  SELECT primary_contact_id, order_id, email
  FROM contacts
  WHERE email IS NOT NULL
    AND NOT REGEXP_CONTAINS(LOWER(TRIM(email)),
      r'^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$')
),
bad_email_format_summary AS (
  SELECT
    COUNT(*) AS bad_email_rows,
    COUNT(DISTINCT order_id) AS affected_orders,
    SAFE_DIVIDE(
      COUNT(*),
      (SELECT COUNT(*) FROM contacts)
    ) AS bad_email_rate
  FROM bad_email_format
),
leading_trailing_email AS (
  SELECT primary_contact_id, order_id, email
  FROM contacts
  WHERE email IS NOT NULL
    AND (email != TRIM(email) OR email != LOWER(email))  -- indicates casing/whitespace still present
),

/* ---------------------------------------------------------------
   8) Completeness vs RAW orders (each raw order should have a row)
---------------------------------------------------------------- */
orders_missing_contact AS (
  SELECT o.order_id
  FROM orders_raw o
  LEFT JOIN contacts c USING (order_id)
  WHERE c.order_id IS NULL
),

/* ---------------------------------------------------------------
   9) primary_contact_id duplicates — informational under new rule
---------------------------------------------------------------- */
dup_primary_contact_id_summary AS (
  SELECT
    COUNT(*) AS distinct_primary_contact_ids_with_dups,
    SUM(cnt) AS total_rows_involved,
    MAX(cnt) AS max_dup_count
  FROM (
    SELECT primary_contact_id, COUNT(*) AS cnt
    FROM contacts
    WHERE primary_contact_id IS NOT NULL
    GROUP BY primary_contact_id
    HAVING COUNT(*) > 1
  )
)
,

/* ---------------------------------------------------------------
   10) Email duplicates — informational (shared inboxes expected)
---------------------------------------------------------------- */
dup_email_summary AS (
  SELECT
    COUNT(*) AS distinct_emails_with_dups,
    SUM(cnt) AS total_rows_involved,
    MAX(cnt) AS max_dup_count
  FROM (
    SELECT LOWER(TRIM(email)) AS email_lc, COUNT(*) AS cnt
    FROM contacts
    WHERE email IS NOT NULL
      AND TRIM(email) != ''
      AND LOWER(TRIM(email)) <> 'no email'
    GROUP BY LOWER(TRIM(email))
    HAVING COUNT(*) > 1
  )
)

-- ===============================================================
-- UNIFIED OUTPUT (every test -> 2 columns)
-- ===============================================================
SELECT 
'INFO' AS severity,
'1. NULL OVERVIEW (informational)' AS test_name, TO_JSON_STRING(t) AS result_json -- null/empty values are allowed (except: contact_surrogate_key, and order_id)
FROM null_overview t

UNION ALL 
SELECT
'ERROR' AS severity,
'2. DUPLICATE rows per ORDER (should be 0)', TO_JSON_STRING(t) -- needs to be zero/not return in order to pass the validation 
FROM dups_by_order t

UNION ALL
SELECT 
'INFO' AS severity,
'3. SURROGATE KEY UNIQUENESS summary', TO_JSON_STRING(t)
FROM sk_uniqueness t

UNION ALL
SELECT 
'WARN' AS severity,
'4. UNKNOWN CONTACT SUMMARY (allowed)', TO_JSON_STRING(t) -- unknowns expected and allowed as they represent purchases at the door 
FROM unknown_summary t

UNION ALL
-- If you didn't add is_unknown_contact column yet, comment out this block:
SELECT 
'WARN' AS severity,
'5A. is_unknown_contact (stored) ≠ derived (should be 0 if column exists)', TO_JSON_STRING(t)
FROM unknown_mismatch_rows t

UNION ALL
SELECT
  'WARN' AS severity,
  '6A. BAD EMAIL FORMAT (summary)',
  TO_JSON_STRING(t)
FROM bad_email_format_summary t

UNION ALL
SELECT 
'WARN' AS severity,
'6B. EMAIL still has casing/whitespace (should be 0 if normalized on load)', TO_JSON_STRING(t)
FROM leading_trailing_email t

UNION ALL
SELECT 
'WARN' AS severity,
'7. COMPLETENESS: RAW orders missing a contact row (should be 0)', TO_JSON_STRING(t)
FROM orders_missing_contact t

UNION ALL
SELECT
  'INFO' AS severity,
  '8A. INFO: Duplicate primary_contact_id (summary)' AS test_name,
  TO_JSON_STRING(t) AS result_json
FROM dup_primary_contact_id_summary t

UNION ALL
SELECT
 'INFO' AS severity,
  '8B. INFO: Duplicate email (summary)',
  TO_JSON_STRING(t)
FROM dup_email_summary t);

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
    'primary_contact',
    severity,
    test_name,
    result_json
FROM validation_results;

ASSERT (
    SELECT COUNT(*)
    FROM validation_results
    WHERE severity = 'ERROR'
) = 0
AS 'Primary Contact validation failed.';