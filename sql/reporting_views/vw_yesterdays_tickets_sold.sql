CREATE OR REPLACE VIEW
rocket-rez-api.rocket_rez_data.vw_yesterdays_tickets_sold
AS

SELECT
  CAST(li.event.schedule.date AS DATE) AS visit_date,
  SUM(rt.quantity) AS headcount
FROM `rocket_rez_data.raw_data_history` r
LEFT JOIN UNNEST(IFNULL(r.lineItems, [])) AS li
LEFT JOIN UNNEST(IFNULL(li.rateTypes, [])) AS rt
WHERE CAST(li.event.schedule.date AS DATE) = DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 1 DAY) -- no change, remains dynamic
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
GROUP BY visit_date;