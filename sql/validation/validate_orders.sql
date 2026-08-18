-- ===============================================================
-- MASTER VALIDATION SCRIPT — json_test.orders  (Option A statuses)
-- Output schema: (test_name STRING, result_json STRING)
-- ===============================================================

CREATE TEMP TABLE validation_results AS(

WITH
/* ---------------------------------------------------------------
   0) TABLE references
---------------------------------------------------------------- */
orders AS (
  SELECT
    order_id,
    conceirge_id,
    created_date,
    modified_date,
    status,
    salesoffice_id,
    salesoffice_name,
    sales_person_firstname,
    sales_person_lastname,
    sales_person_id,
    web_order,
    total,
    tax_total,
    subtotal,
    discount_total,
    gratuity_total,
    currency,
    question,
    contact_group_id,
    contact_group_name
  FROM `rocket_rez_data.orders`
),
orders_raw AS (
  SELECT DISTINCT r.id AS order_id
  FROM `rocket_rez_data.raw_data` r
),
line_items AS (
  SELECT DISTINCT order_id
  FROM `rocket_rez_data.line_items`
),
primary_contact AS (
  SELECT DISTINCT order_id
  FROM `rocket_rez_data.primary_contact`
),

/* ---------------------------------------------------------------
   1) NOT NULL / REQUIRED overview
---------------------------------------------------------------- */
null_overview AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNTIF(order_id IS NULL)         AS null_order_id,
    COUNTIF(created_date IS NULL)     AS null_created_date,
    COUNTIF(modified_date IS NULL)    AS null_modified_date,
    COUNTIF(total IS NULL)            AS null_total,
    COUNTIF(subtotal IS NULL)         AS null_subtotal,
    COUNTIF(tax_total IS NULL)        AS null_tax_total,
    COUNTIF(discount_total IS NULL)   AS null_discount_total,
    COUNTIF(gratuity_total IS NULL)   AS null_gratuity_total,
    COUNTIF(currency IS NULL OR TRIM(currency) = '') AS null_or_empty_currency
  FROM orders
),

/* ---------------------------------------------------------------
   2) PRIMARY KEY uniqueness on order_id
---------------------------------------------------------------- */
dup_order_id AS (
  SELECT order_id, COUNT(*) AS cnt
  FROM orders
  GROUP BY order_id
  HAVING COUNT(*) > 1
),

/* ---------------------------------------------------------------
   3) Timestamp sanity: created ≤ modified
---------------------------------------------------------------- */
bad_timestamp_order AS (
  SELECT order_id, created_date, modified_date
  FROM orders
  WHERE created_date IS NOT NULL
    AND modified_date IS NOT NULL
    AND modified_date < created_date
),

/* ---------------------------------------------------------------
   4) Currency format: strict ISO-4217 (3 letters)
---------------------------------------------------------------- */
bad_currency_format AS (
  SELECT order_id, currency
  FROM orders
  WHERE currency IS NOT NULL
    AND NOT REGEXP_CONTAINS(currency, r'^[A-Z]{3}$')
),

/* ---------------------------------------------------------------
   5) Status sanity — Option A allow-list (source vocabulary kept)
---------------------------------------------------------------- */
bad_status AS (
  SELECT order_id, status
  FROM orders
  WHERE status IS NOT NULL
    AND UPPER(TRIM(REGEXP_REPLACE(status, r'\p{Zs}+', ' ')))
        NOT IN (
          'OPEN','PENDING','PAID','COMPLETED','CANCELLED','REFUNDED',
          'ACTIVE','ESTIMATE','VOID', 'WAIT/HOLD'
        )
),

/* ---------------------------------------------------------------
   6) FINANCIAL MISMATCH — RocketRez multi-model logic (FINAL)
      Order fails ONLY if it fails ALL allowed explicit-tax models
---------------------------------------------------------------- */
/* ---------------------------------------------------------------
   6) FINANCIAL MISMATCH — RocketRez multi-model logic (FINAL + FEES)
      Order fails ONLY if it fails ALL allowed explicit-tax models
      INCLUDING fee-based residuals (Model F)
---------------------------------------------------------------- */
financial_mismatch AS (
  SELECT
    order_id,
    status,
    subtotal,
    discount_total,
    tax_total,
    gratuity_total,
    total,

    -- Residual amount (potential fees)
    ROUND(
      total - (subtotal + tax_total + gratuity_total),
      2
    ) AS fee_residual,

    -- Model A: discount reduces taxable base
    ABS(
      ROUND(total,2) -
      ROUND(subtotal - discount_total + tax_total + gratuity_total, 2)
    ) AS delta_model_a,

    -- Model B: tax applied pre-discount
    ABS(
      ROUND(total,2) -
      ROUND(subtotal + tax_total + gratuity_total, 2)
    ) AS delta_model_b,

    -- Model D: discount as post-tax payment / credit
    ABS(
      ROUND(total,2) -
      ROUND(subtotal + tax_total + discount_total + gratuity_total, 2)
    ) AS delta_model_d,

    -- Model E: partially-taxable discount (legacy mixed-tax)
    ABS(
      ROUND(total,2) -
      ROUND(
        subtotal
        + tax_total
        + discount_total
        - (discount_total * SAFE_DIVIDE(tax_total, NULLIF(subtotal,0))),
        2
      )
    ) AS delta_model_e

  FROM orders

  WHERE
    -- Only validate financially meaningful orders
    UPPER(status) NOT IN ('CANCELLED','VOID','REFUNDED')
    AND COALESCE(tax_total,0) > 0

    -- Fail ONLY if all known models fail
    AND ABS(ROUND(total,2) - ROUND(subtotal - discount_total + tax_total + gratuity_total,2)) > 0.10
    AND ABS(ROUND(total,2) - ROUND(subtotal + tax_total + gratuity_total,2)) > 0.10
    AND ABS(ROUND(total,2) - ROUND(subtotal + tax_total + discount_total + gratuity_total,2)) > 0.10
    AND ABS(
          ROUND(total,2) -
          ROUND(
            subtotal
            + tax_total
            + discount_total
            - (discount_total * SAFE_DIVIDE(tax_total, NULLIF(subtotal,0))),
            2
          )
        ) > 0.10

    -- Model F: fee-based residuals (ACCEPT if true, so FAIL only if NOT true)
    AND NOT (
      ROUND(total - (subtotal + tax_total + gratuity_total), 2)
        BETWEEN 0.01 AND 50.00
    )
),


/* ---------------------------------------------------------------
   7) Completeness vs RAW (windowing optional; compares IDs)
---------------------------------------------------------------- */
raw_missing_in_orders AS (
  SELECT r.order_id
  FROM orders_raw r
  LEFT JOIN orders o USING (order_id)
  WHERE o.order_id IS NULL
),
orders_not_in_raw AS (
  SELECT o.order_id
  FROM orders o
  LEFT JOIN orders_raw r USING (order_id)
  WHERE r.order_id IS NULL
),

/* ---------------------------------------------------------------
   8) Referential integrity with line_items and primary_contact
---------------------------------------------------------------- */
orders_zero_line_items_summary AS (
  SELECT
    COUNT(*) AS orders_with_zero_line_items
  FROM orders o
  LEFT JOIN line_items li USING (order_id)
  WHERE li.order_id IS NULL
),
orders_missing_primary_contact_summary AS (
  SELECT
    COUNT(*) AS orders_missing_primary_contact
  FROM orders o
  LEFT JOIN primary_contact pc USING (order_id)
  WHERE pc.order_id IS NULL
),
orders_multi_primary_contact_summary AS (
  SELECT
    COUNT(*) AS orders_with_multiple_primary_contacts
  FROM (
    SELECT pc.order_id
    FROM `rocket_rez_data.primary_contact` pc
    GROUP BY pc.order_id
    HAVING COUNT(*) > 1
  )
),

/* ---------------------------------------------------------------
   9) Descriptive rollups (quick anomaly checks)
---------------------------------------------------------------- */
financial_rollup AS (
  SELECT
    COUNT(*) AS n_orders,
    SUM(COALESCE(total,0))          AS sum_total,
    SUM(COALESCE(subtotal,0))       AS sum_subtotal,
    SUM(COALESCE(tax_total,0))      AS sum_tax_total,
    SUM(COALESCE(gratuity_total,0)) AS sum_gratuity_total,
    SUM(COALESCE(discount_total,0)) AS sum_discount_total
  FROM orders
),
web_vs_pos AS (
  SELECT
    web_order,
    COUNT(*) AS n,
    SUM(COALESCE(total,0)) AS total_amount
  FROM orders
  GROUP BY web_order
),
status_counts AS (
  SELECT
    UPPER(TRIM(REGEXP_REPLACE(status, r'\p{Zs}+', ' '))) AS status_norm,
    COUNT(*) AS n,
    SUM(COALESCE(total,0)) AS total_amount
  FROM orders
  GROUP BY status_norm
)

-- ===============================================================
-- UNIFIED OUTPUT (two columns for every test)
-- ===============================================================

SELECT
  'INFO' AS severity,
  '1. NULL OVERVIEW (informational)' AS test_name,
  TO_JSON_STRING(t) AS result_json
FROM null_overview t

UNION ALL
SELECT 
 'INFO' AS severity,
'2. DUPLICATE order_id (should be 0)', TO_JSON_STRING(t)
FROM dup_order_id t

UNION ALL
SELECT 
 'INFO' AS severity,
'3. BAD TIMESTAMP ORDER (created_date > modified_date) (should be 0)', TO_JSON_STRING(t)
FROM bad_timestamp_order t

UNION ALL
SELECT 
 'INFO' AS severity,
'4. BAD CURRENCY FORMAT (should be 0)', TO_JSON_STRING(t)
FROM bad_currency_format t

UNION ALL
SELECT 
 'INFO' AS severity,
'5. BAD STATUS (outside allow-list: Option A) (should be 0)', TO_JSON_STRING(t)
FROM bad_status t

UNION ALL
SELECT
  'ERROR' AS severity,
  '6. FINANCIAL MISMATCH (explicit-tax models A/B/D/E all failed)',
  TO_JSON_STRING(t)
FROM financial_mismatch t

UNION ALL
SELECT 
 'INFO' AS severity,
'7. COMPLETENESS: RAW order missing in orders table (should be 0)', TO_JSON_STRING(t)
FROM raw_missing_in_orders t

UNION ALL
SELECT 
 'INFO' AS severity,
'8A. REF: Orders with ZERO line items (should be 0)', TO_JSON_STRING(t)
FROM orders_zero_line_items_summary t

UNION ALL
SELECT 
 'INFO' AS severity,
'8B. REF: Orders missing primary contact (should be 0)', TO_JSON_STRING(t)
FROM orders_missing_primary_contact_summary t

UNION ALL
SELECT 
 'INFO' AS severity,
'8C. REF: Orders with >1 primary contact (should be 0)', TO_JSON_STRING(t)
FROM orders_multi_primary_contact_summary t

UNION ALL
SELECT 
 'INFO' AS severity,
'9A. ROLLUP: financial totals (informational)', TO_JSON_STRING(t)
FROM financial_rollup t

UNION ALL
SELECT 
 'INFO' AS severity,
'9B. ROLLUP: web vs non-web mix (informational)', TO_JSON_STRING(t)
FROM web_vs_pos t

UNION ALL
SELECT 
 'INFO' AS severity,
'9C. ROLLUP: status counts (informational)', TO_JSON_STRING(t)
FROM status_counts t);

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
    'orders',
    severity,
    test_name,
    result_json
FROM validation_results;

ASSERT (
    SELECT COUNT(*)
    FROM validation_results
    WHERE severity = 'ERROR'
) = 0
AS 'Orders validation failed.';