CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_ai.vw_visitor_count_by_sales_channel`
AS

SELECT
  li.salesOfficeName AS sales_office,
  SUM(rt.quantity) AS visitor_count

FROM `rocket-rez-api.rocket_rez_data.raw_data_history` AS r

LEFT JOIN UNNEST(IFNULL(r.lineItems, [])) AS li
LEFT JOIN UNNEST(IFNULL(li.rateTypes, [])) AS rt

WHERE CAST(li.event.schedule.date AS DATE) >= DATE '2026-01-01'-- update to 2027-01-01
  AND CAST(li.event.schedule.date AS DATE) < DATE '2027-01-01'-- update to 2028-01-01

  AND li.type = 'Rate'

  AND rt.rateType IN (
    'Adult (13-64)',
    'Child (4-12)',
    'Senior (65+)',
    'Student (9-12)',
    'Student (K-8)',
    'Under 3'
  )

  AND UPPER(r.status) NOT IN (
    'CANCELLED',
    'VOID',
    'VOIDED',
    'RETURNPENDING',
    'RETURNPROCESSED'
  )

GROUP BY
  sales_office

ORDER BY
  visitor_count DESC;