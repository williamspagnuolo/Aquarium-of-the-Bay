MERGE `rocket_rez_data.primary_contact` AS tgt
USING (
  SELECT
    -- Surrogate key generated per incoming row (used only when inserting)
    GENERATE_UUID() AS contact_surrogate_key,

    -- Source metadata (not a unique key)
    r.primaryContact.id                                   AS primary_contact_id,

    -- Normalized identity fields
    TRIM(r.primaryContact.firstName)                      AS first_name,
    TRIM(r.primaryContact.lastName)                       AS last_name,
    NULLIF(LOWER(TRIM(r.primaryContact.email)), 'no email') AS email,
    NULLIF(REGEXP_REPLACE(LOWER(TRIM(r.primaryContact.phone)), r'[^0-9x]', ''), '') AS phone,

    -- Address (trimmed)
    TRIM(r.primaryContact.billingAddress.addressLine1)    AS address_line1,
    TRIM(r.primaryContact.billingAddress.addressLine2)    AS address_line2,
    TRIM(r.primaryContact.billingAddress.city)            AS city,
    TRIM(r.primaryContact.billingAddress.province)        AS province,
    TRIM(r.primaryContact.billingAddress.postalCode)      AS postal_code,
    TRIM(r.primaryContact.billingAddress.country)         AS country,

    -- Business grain: one contact snapshot per order
    r.id                                                  AS order_id,

    -- Walk-up/unknown contact flag (derived)
    CASE
      WHEN (r.primaryContact.email IS NULL 
            OR LOWER(TRIM(r.primaryContact.email)) = 'no email' 
            OR TRIM(r.primaryContact.email) = '')
       AND (r.primaryContact.firstName IS NULL OR TRIM(r.primaryContact.firstName) = '')
       AND (r.primaryContact.lastName  IS NULL OR TRIM(r.primaryContact.lastName)  = '')
       AND (r.primaryContact.phone IS NULL
            OR REGEXP_REPLACE(LOWER(TRIM(r.primaryContact.phone)), r'[^0-9x]', '') = '')
      THEN TRUE
      ELSE FALSE
    END AS is_unknown_contact
  FROM `rocket_rez_data.raw_data` AS r
) AS src
ON tgt.order_id = src.order_id   -- natural business grain

WHEN NOT MATCHED THEN
  INSERT (
    contact_surrogate_key,
    primary_contact_id,
    first_name,
    last_name,
    email,
    phone,
    address_line1,
    address_line2,
    city,
    province,
    postal_code,
    country,
    order_id,
    is_unknown_contact
  )
  VALUES (
    src.contact_surrogate_key,
    src.primary_contact_id,
    src.first_name,
    src.last_name,
    src.email,
    src.phone,
    src.address_line1,
    src.address_line2,
    src.city,
    src.province,
    src.postal_code,
    src.country,
    src.order_id,
    src.is_unknown_contact
  )

-- Optional: keep the latest known contact details if a returning order reappears
-- (Only include this WHEN MATCHED block if you want to refresh contact info)
WHEN MATCHED AND (
    tgt.first_name        IS DISTINCT FROM src.first_name OR
    tgt.last_name         IS DISTINCT FROM src.last_name  OR
    tgt.email             IS DISTINCT FROM src.email      OR
    tgt.phone             IS DISTINCT FROM src.phone      OR
    tgt.address_line1     IS DISTINCT FROM src.address_line1 OR
    tgt.address_line2     IS DISTINCT FROM src.address_line2 OR
    tgt.city              IS DISTINCT FROM src.city       OR
    tgt.province          IS DISTINCT FROM src.province   OR
    tgt.postal_code       IS DISTINCT FROM src.postal_code OR
    tgt.country           IS DISTINCT FROM src.country    OR
    tgt.primary_contact_id IS DISTINCT FROM src.primary_contact_id OR
    tgt.is_unknown_contact IS DISTINCT FROM src.is_unknown_contact
)
THEN UPDATE SET
  tgt.primary_contact_id  = src.primary_contact_id,
  tgt.first_name          = src.first_name,
  tgt.last_name           = src.last_name,
  tgt.email               = src.email,
  tgt.phone               = src.phone,
  tgt.address_line1       = src.address_line1,
  tgt.address_line2       = src.address_line2,
  tgt.city                = src.city,
  tgt.province            = src.province,
  tgt.postal_code         = src.postal_code,
  tgt.country             = src.country,
  tgt.is_unknown_contact  = src.is_unknown_contact;

ASSERT (
  SELECT COUNT(*) FROM (
    SELECT order_id
    FROM `rocket_rez_data.primary_contact`
    GROUP BY order_id
    HAVING COUNT(*) > 1
  )
) = 0 AS 'Duplicate primary_contact rows per order_id detected.';
  