CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_ai.vw_primary_contact_masked`
AS
SELECT
  -- Non-PII columns here.
  contact_surrogate_key,
  primary_contact_id,
  city,
  province,
  postal_code,
  country,
  order_id,
  is_unknown_contact,

  -- Mask the PII columns here.

  CAST(NULL AS STRING) AS first_name,
  CAST(NULL AS STRING) AS last_name,

  CASE
    WHEN email IS NULL THEN NULL
    WHEN STRPOS(email, '@') > 1 THEN
      CONCAT('XXXXX', SUBSTR(email, STRPOS(email, '@')))
    ELSE 'XXXXX'
  END AS email,

  CASE
    WHEN phone IS NULL THEN NULL
    WHEN LENGTH(phone) >= 4 THEN
      CONCAT(
        REPEAT('X', LENGTH(phone) - 4),
        RIGHT(phone, 4)
      )
    ELSE REPEAT('X', LENGTH(phone))
  END AS phone,

  CAST(NULL AS STRING) AS address_line1,
  CAST(NULL AS STRING) AS address_line2

FROM `rocket-rez-api.rocket_rez_data.primary_contact`