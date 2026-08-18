-- ===============================================================
-- MASTER VALIDATION SCRIPT FOR json_test.line_items
-- Validates: table grain/duplicates, completeness vs RAW (NULL-safe),
-- surrogate key uniqueness, null/negative checks, serials duplicates,
-- soft math reasonableness, and raw fan-out duplicates.
-- ===============================================================
CREATE TEMP TABLE validation_results AS(

WITH
-- ---------------------------------------------------------------
-- 0) RAW flatten: build the source at the intended grain
-- ---------------------------------------------------------------
raw_flat AS (
  SELECT DISTINCT
    r.id                                        AS order_id,
    li.id                                       AS line_item_id,
    ra.rateType                                 AS rate_type,
    li.type                                     AS line_item_type,
    li.typeId                                   AS line_item_type_id,
    li.name                                     AS line_item_name,
    CAST(li.productId AS STRING)                AS product_id,
    CAST(ra.price AS NUMERIC)                   AS line_item_price,
    CAST(ra.taxTotal AS NUMERIC)                AS line_item_tax_total,
    CAST(ra.subTotal AS NUMERIC)                AS line_item_subtotal,
    ARRAY_TO_STRING(ra.serials, ',')            AS serials,
    ra.quantity                                 AS line_item_quantity,
    CAST(ra.couponAmount AS NUMERIC)            AS coupon_amount,
    CAST(ra.priceOverrideAmount AS NUMERIC)     AS price_override_amount
  FROM `rocket_rez_data.raw_data` AS r
  LEFT JOIN UNNEST(IFNULL(r.lineItems, [])) AS li ON TRUE
  LEFT JOIN UNNEST(IFNULL(li.rateTypes, [])) AS ra ON TRUE
),

-- ---------------------------------------------------------------
-- 1) Composite, NULL-safe keys for RAW and TABLE
--    (avoid NULL ≠ NULL join problems by normalizing to strings)
-- ---------------------------------------------------------------
raw_keys AS (
  SELECT DISTINCT
    order_id, line_item_id, rate_type,
    CONCAT(
      'O:', IFNULL(CAST(order_id AS STRING), 'NULL'), '|',
      'LI:', IFNULL(CAST(line_item_id AS STRING), 'NULL'), '|',
      'RT:', IFNULL(rate_type, 'NULL')
    ) AS li_key
  FROM raw_flat
  -- Optional: if you want to ignore rows with fully NULL key
  -- WHERE NOT (order_id IS NULL AND line_item_id IS NULL AND rate_type IS NULL)
),

tbl AS (
  SELECT * FROM `rocket_rez_data.line_items`
),

tbl_keys AS (
  SELECT DISTINCT
    order_id, line_item_id, rate_type,
    CONCAT(
      'O:', IFNULL(CAST(order_id AS STRING), 'NULL'), '|',
      'LI:', IFNULL(CAST(line_item_id AS STRING), 'NULL'), '|',
      'RT:', IFNULL(rate_type, 'NULL')
    ) AS li_key
  FROM tbl
),

-- ---------------------------------------------------------------
-- 2) RAW fan-out duplicates (same business key > 1 in source)
-- ---------------------------------------------------------------
raw_dups AS (
  SELECT li_key, COUNT(*) AS cnt
  FROM raw_keys
  WHERE line_item_id IS NOT NULL
    AND rate_type IS NOT NULL
  GROUP BY li_key
  HAVING COUNT(*) > 1
),

-- ---------------------------------------------------------------
-- 3) Table duplicates at intended grain
-- ---------------------------------------------------------------
tbl_dups AS (
  SELECT li_key, COUNT(*) AS cnt
  FROM tbl_keys
  GROUP BY li_key
  HAVING COUNT(*) > 1
),

-- ---------------------------------------------------------------
-- 4) Completeness: RAW → TABLE (missing in table)
-- ---------------------------------------------------------------
missing_in_table AS (
  SELECT r.order_id, r.line_item_id, r.rate_type, r.li_key
  FROM raw_keys r
  LEFT JOIN tbl_keys t USING (li_key)
  WHERE t.li_key IS NULL
    AND r.line_item_id IS NOT NULL
    AND r.rate_type IS NOT NULL
),

-- ---------------------------------------------------------------
-- 5) Completeness: TABLE → RAW (extras in table)
-- ---------------------------------------------------------------

extra_in_table AS (
  SELECT t.order_id, t.line_item_id, t.rate_type, t.li_key
  FROM tbl_keys t
  LEFT JOIN raw_keys r USING (li_key)
  WHERE r.li_key IS NULL
    AND t.line_item_id IS NOT NULL
    AND t.rate_type IS NOT NULL
),

-- ---------------------------------------------------------------
-- 6) Null counters for key/critical columns (overview)
-- ---------------------------------------------------------------
null_counts AS (
  SELECT
    COUNTIF(order_id IS NULL)            AS null_order_id,
    COUNTIF(line_item_id IS NULL)        AS null_line_item_id,
    COUNTIF(rate_type IS NULL)           AS null_rate_type,
    COUNTIF(line_item_price IS NULL)     AS null_price,
    COUNTIF(line_item_quantity IS NULL)  AS null_quantity,
    COUNTIF(line_item_subtotal IS NULL)  AS null_subtotal,
    COUNTIF(line_item_tax_total IS NULL) AS null_tax_total
  FROM tbl
),

-- ---------------------------------------------------------------
-- 7) Negative numbers (flag any obviously invalid negatives)
--     (Adjust if your business allows negatives in specific fields)
-- ---------------------------------------------------------------
negatives AS (
  SELECT
    surrogate_key, order_id, line_item_id, rate_type,
    line_item_price, line_item_quantity, line_item_tax_total, line_item_subtotal,
    coupon_amount, price_override_amount
  FROM tbl
  WHERE
    line_item_price        < 0 OR
    line_item_quantity     < 0 OR
    line_item_tax_total    < 0 OR
    line_item_subtotal     < 0
),

-- ---------------------------------------------------------------
-- 8) Per-unit override pricing model
-- ---------------------------------------------------------------
math_mismatch AS (
  WITH li AS (
    SELECT
      surrogate_key,
      order_id,
      line_item_id,
      rate_type,
      COALESCE(CAST(line_item_price AS NUMERIC), 0)       AS price,
      COALESCE(CAST(line_item_quantity AS NUMERIC), 0)    AS qty,
      COALESCE(CAST(line_item_subtotal AS NUMERIC), 0)    AS subtotal,
      COALESCE(coupon_amount, 0)                          AS coupon,
      COALESCE(price_override_amount, 0)                  AS override
    FROM `rocket_rez_data.line_items`
  ),
  evals AS (
    SELECT
      surrogate_key, order_id, line_item_id, rate_type,
      price, qty, subtotal, coupon, override,
      ((price + override) * qty) - coupon                       AS expected,
      ABS(subtotal - (((price + override) * qty) - coupon))     AS abs_delta
    FROM li
  )
  SELECT *
  FROM evals
  WHERE abs_delta > 0.02   -- tolerance for rounding
),

math_mismatch_summary AS (
  SELECT
    COUNT(*)                        AS line_items_affected,
    COUNT(DISTINCT order_id)        AS orders_affected,
    MAX(abs_delta)                  AS max_abs_delta
  FROM math_mismatch
),

-- ---------------------------------------------------------------
-- 9) Serials with duplicate tokens inside a row (comma-separated)
-- ---------------------------------------------------------------
serials_dup_tokens AS (
  SELECT
    surrogate_key, order_id, line_item_id, rate_type, serials
  FROM tbl
  WHERE serials IS NOT NULL
    AND ARRAY_LENGTH(SPLIT(serials, ',')) != ARRAY_LENGTH(
          ARRAY(SELECT DISTINCT TRIM(x) FROM UNNEST(SPLIT(serials, ',')) AS x)
        )
),

-- ---------------------------------------------------------------
-- 10) Surrogate key uniqueness summary
-- ---------------------------------------------------------------
sk_summary AS (
  SELECT
    (SELECT COUNT(*) FROM tbl)                                  AS total_rows,
    (SELECT COUNT(DISTINCT surrogate_key) FROM tbl)             AS distinct_surrogate_keys
)

-- ===============================================================
-- UNIFIED OUTPUT (two columns for every test)
-- ===============================================================
SELECT
  'ERROR' AS severity,
  '1. TABLE DUPLICATES at (order_id, line_item_id, rate_type) — should be 0' AS test_name,
  TO_JSON_STRING(t) AS result_json
FROM tbl_dups t

UNION ALL
SELECT
 'ERROR' AS severity,
  '2. RAW → TABLE MISSING keys — should be 0',
  TO_JSON_STRING(t)
FROM missing_in_table t

UNION ALL
SELECT
 'INFO' AS severity,
  '3. SURROGATE KEY UNIQUENESS summary', -- both counts should be equal in order for this test to be valid 
  TO_JSON_STRING(t)
FROM sk_summary t

UNION ALL
SELECT
  'INFO' AS severity,
  '4. NULL COUNTS for key/critical columns (investigate non-zeros)', -- only need to be concerned if order_id returns anthing other than 0
  TO_JSON_STRING(t)
FROM null_counts t

UNION ALL
SELECT
 'ERROR' AS severity,
  '5. NEGATIVE VALUES detected (should be 0 rows unless allowed)',
  TO_JSON_STRING(t)
FROM negatives t

UNION ALL
SELECT
  'INFO' AS severity,
  '6. SOFT MATH MISMATCH (summary; rounding tolerance)',
  TO_JSON_STRING(t)
FROM math_mismatch_summary t

UNION ALL
SELECT
 'ERROR' AS severity,
  '7. SERIALS have duplicate tokens within the same row',
  TO_JSON_STRING(t)
FROM serials_dup_tokens t

UNION ALL
SELECT
 'ERROR' AS severity,
  '8. RAW FAN-OUT duplicates (same business key > 1 in RAW)',
  TO_JSON_STRING(t)
FROM raw_dups t);

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
    'line_items',
    severity,
    test_name,
    result_json
FROM validation_results;

ASSERT (
    SELECT COUNT(*)
    FROM validation_results
    WHERE severity = 'ERROR'
) = 0
AS 'Line Items validation failed.';

-- 