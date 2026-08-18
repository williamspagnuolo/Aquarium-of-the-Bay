MERGE `rocket_rez_data.line_items` AS tgt
USING (
  SELECT
    -- Warehouse surrogate key generated per incoming row (used only when inserting)
    GENERATE_UUID()                                  AS surrogate_key,

    -- Business key columns
    r.id                                             AS order_id,
    li.id                                            AS line_item_id,
    ra.rateType                                      AS rate_type,

    -- Attributes (normalized / typed)
    li.type                                          AS line_item_type,
    li.typeId                                        AS line_item_type_id,
    li.name                                          AS line_item_name,
    CAST(li.productId AS STRING)                     AS product_id,
    CAST(ra.price AS NUMERIC)                        AS line_item_price,
    CAST(ra.taxTotal AS NUMERIC)                     AS line_item_tax_total,
    CAST(ra.subTotal AS NUMERIC)                     AS line_item_subtotal,
    ARRAY_TO_STRING(ra.serials, ',')                 AS serials,
    ra.quantity                                      AS line_item_quantity,
    CAST(ra.couponAmount AS NUMERIC)                 AS coupon_amount,
    CAST(ra.priceOverrideAmount AS NUMERIC)          AS price_override_amount
  FROM `rocket_rez_data.raw_data` AS r
  LEFT JOIN UNNEST(IFNULL(r.lineItems, [])) AS li ON TRUE
  LEFT JOIN UNNEST(IFNULL(li.rateTypes, [])) AS ra ON TRUE
  WHERE li.id IS NOT NULL
    AND ra.rateType IS NOT NULL
) AS src
ON  tgt.order_id      = src.order_id
AND tgt.line_item_id  = src.line_item_id
AND tgt.rate_type     = src.rate_type

WHEN NOT MATCHED THEN
  INSERT (
    surrogate_key,
    line_item_id,
    line_item_type,
    line_item_type_id,
    line_item_name,
    product_id,
    line_item_price,
    line_item_tax_total,
    line_item_subtotal,
    serials,
    line_item_quantity,
    rate_type,
    coupon_amount,
    price_override_amount,
    order_id
  )
  VALUES (
    src.surrogate_key,
    src.line_item_id,
    src.line_item_type,
    src.line_item_type_id,
    src.line_item_name,
    src.product_id,
    src.line_item_price,
    src.line_item_tax_total,
    src.line_item_subtotal,
    src.serials,
    src.line_item_quantity,
    src.rate_type,
    src.coupon_amount,
    src.price_override_amount,
    src.order_id
  );


ASSERT (
  SELECT COUNT(*) FROM (
    SELECT order_id, line_item_id, rate_type
    FROM `rocket_rez_data.line_items`
    GROUP BY order_id, line_item_id, rate_type
    HAVING COUNT(*) > 1
  )
) = 0 AS 'Duplicate line_items at (order_id, line_item_id, rate_type) detected.';