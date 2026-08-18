-- 1) TEMP UDF: normalize currencyName to strict 3-letter ISO or NULL
CREATE TEMP FUNCTION normalize_currency(s STRING) AS (
  (
    WITH raw AS (
      SELECT s AS val
    ),
    step1 AS (
      -- Replace any Unicode space separators with a regular space, then TRIM and UPPER
      SELECT UPPER(TRIM(REGEXP_REPLACE(val, r'\p{Zs}+', ' '))) AS v
      FROM raw
    ),
    step2 AS (
      -- Map common non-ISO forms to ISO
      SELECT
        CASE
          WHEN v IS NULL OR v = '' THEN NULL
          WHEN REGEXP_CONTAINS(v, r'^\$|^US\$|^USD\$|^U\.S\.D\.$') THEN 'USD'
          ELSE v
        END AS v2
      FROM step1
    ),
    step3 AS (
      -- If not already a clean 3-letter code, try to extract the first 3-letter token
      SELECT
        CASE
          WHEN REGEXP_CONTAINS(v2, r'^[A-Z]{3}$') THEN v2
          ELSE REGEXP_EXTRACT(v2, r'([A-Z]{3})')
        END AS v3
      FROM step2
    )
    SELECT v3 FROM step3
  )
);

-- 2) Idempotent MERGE: orders
MERGE `rocket_rez_data.orders` AS tgt
USING (
  SELECT
    r.id                                  AS order_id,
    r.conceirgeId                         AS conceirge_id,
    r.createdDate                         AS created_date,
    r.modifiedDate                        AS modified_date,
    r.status                              AS status,
    r.salesOfficeId                       AS salesoffice_id,
    r.salesOfficeName                     AS salesoffice_name,
    r.salesPersonFirstName                AS sales_person_firstname,
    r.salesPersonLastName                 AS sales_person_lastname,
    r.salesPersonId                       AS sales_person_id,
    r.isWebOrder                          AS web_order,
    CAST(r.total         AS NUMERIC)      AS total,
    CAST(r.taxTotal      AS NUMERIC)      AS tax_total,
    CAST(r.subTotal      AS NUMERIC)      AS subtotal,
    CAST(r.discountTotal AS NUMERIC)      AS discount_total,
    CAST(r.gratuityTotal AS NUMERIC)      AS gratuity_total,

    -- Normalize your only source field: currencyName
    normalize_currency(r.currencyName)    AS currency,

    TO_JSON_STRING(r.questions)           AS question,
    r.contactGroupId                      AS contact_group_id,
    r.contactGroupName                    AS contact_group_name
  FROM `rocket_rez_data.raw_data` r
) AS src
ON tgt.order_id = src.order_id

WHEN NOT MATCHED THEN
  INSERT (
    order_id, conceirge_id, created_date, modified_date, status,
    salesoffice_id, salesoffice_name, sales_person_firstname, sales_person_lastname,
    sales_person_id, web_order, total, tax_total, subtotal, discount_total,
    gratuity_total, currency, question, contact_group_id, contact_group_name
  )
  VALUES (
    src.order_id, src.conceirge_id, src.created_date, src.modified_date, src.status,
    src.salesoffice_id, src.salesoffice_name, src.sales_person_firstname, src.sales_person_lastname,
    src.sales_person_id, src.web_order, src.total, src.tax_total, src.subtotal, src.discount_total,
    src.gratuity_total, src.currency, src.question, src.contact_group_id, src.contact_group_name
  )

-- Optional upsert of changed fields (NULL-safe comparisons).
WHEN MATCHED AND (
  tgt.currency        IS DISTINCT FROM src.currency        OR
  tgt.total           IS DISTINCT FROM src.total           OR
  tgt.tax_total       IS DISTINCT FROM src.tax_total       OR
  tgt.subtotal        IS DISTINCT FROM src.subtotal        OR
  tgt.discount_total  IS DISTINCT FROM src.discount_total  OR
  tgt.gratuity_total  IS DISTINCT FROM src.gratuity_total  OR
  tgt.status          IS DISTINCT FROM src.status
)
THEN UPDATE SET
  tgt.currency        = src.currency,
  tgt.total           = src.total,
  tgt.tax_total       = src.tax_total,
  tgt.subtotal        = src.subtotal,
  tgt.discount_total  = src.discount_total,
  tgt.gratuity_total  = src.gratuity_total,
  tgt.status          = src.status;

-- 3) Inline ASSERT: fail the job if any non-ISO currency slips in
ASSERT (
  SELECT COUNT(*)
  FROM `rocket_rez_data.orders`
  WHERE currency IS NOT NULL
    AND NOT REGEXP_CONTAINS(currency, r'^[A-Z]{3}$')
) = 0 AS 'Bad currency format detected in json_test.orders.';