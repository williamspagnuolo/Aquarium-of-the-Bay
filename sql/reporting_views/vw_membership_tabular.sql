CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_data.vw_membership_tabular`
AS

SELECT
  TRIM(li.name) AS membership_name,

  COUNT(DISTINCT r.id) AS orders,

  SUM(rt.quantity) AS memberships_sold,

  ROUND(
    SUM(rt.subTotal),
    2
  ) AS membership_revenue

FROM `rocket-rez-api.rocket_rez_data.raw_data_history` AS r

LEFT JOIN UNNEST(IFNULL(r.lineItems, [])) AS li
LEFT JOIN UNNEST(IFNULL(li.rateTypes, [])) AS rt

WHERE li.type = 'Membership'

  AND DATE(r.createdDate, 'America/Los_Angeles') >= DATE '2026-01-01'-- update to 2027-01-01
  AND DATE(r.createdDate, 'America/Los_Angeles') < DATE '2027-01-01'-- update to 2028-01-01

  AND UPPER(REPLACE(r.status, ' ', '')) NOT IN (
    'VOID',
    'VOIDED',
    'CANCELLED',
    'RETURNPENDING',
    'RETURNPROCESSED'
  )

GROUP BY
  membership_name

ORDER BY
  memberships_sold DESC;