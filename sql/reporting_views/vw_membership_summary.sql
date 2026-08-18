CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_data.vw_membership_summary`
AS

SELECT
  SUM(
    CASE
      WHEN STARTS_WITH(TRIM(li.name), 'New ')
      THEN rt.quantity
      ELSE 0
    END
  ) AS new_memberships_sold,

  SUM(
    CASE
      WHEN li.type = 'Membership'
        AND NOT STARTS_WITH(TRIM(li.name), 'New ')
        AND NOT STARTS_WITH(TRIM(li.name), 'Volunteer')
        AND NOT STARTS_WITH(TRIM(li.name), 'Employee')
      THEN rt.quantity
      ELSE 0
    END
  ) AS membership_renewals,

  ROUND(
    SUM(
      CASE
        WHEN li.type = 'Membership'
          AND NOT STARTS_WITH(TRIM(li.name), 'Volunteer')
          AND NOT STARTS_WITH(TRIM(li.name), 'Employee')
        THEN rt.subTotal
        ELSE 0
      END
    ),
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
  );