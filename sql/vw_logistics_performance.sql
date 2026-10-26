USE olist_ecommerce;


GO
CREATE OR ALTER VIEW vw_logistics_performance
AS
WITH   OrderReviewsAgg
AS     (SELECT   order_id,
                 AVG(CAST (review_score AS FLOAT)) AS avg_review_score,
                 COUNT(review_id) AS total_reviews
        FROM     fact_order_reviews
        GROUP BY order_id),
       OrderItemsAgg
AS     (SELECT   order_id,
                 SUM(price) AS total_order_value,
                 SUM(freight_value) AS total_freight_value,
                 COUNT(order_item_id) AS total_item_count
        FROM     fact_order_items
        GROUP BY order_id)
SELECT fo.order_id,
       fo.customer_id,
       c.customer_city,
       c.customer_state,
       CAST (fo.order_purchase_timestamp AS DATE) AS purchase_date,
       CAST (CONVERT (VARCHAR (8), fo.order_purchase_timestamp, 112) AS INT) AS purchase_date_key,
       fo.order_delivered_customer_date,
       fo.order_estimated_delivery_date,
       DATEDIFF(DAY, fo.order_purchase_timestamp, fo.order_delivered_customer_date) AS actual_delivery_days,
       DATEDIFF(DAY, fo.order_purchase_timestamp, fo.order_estimated_delivery_date) AS estimated_delivery_days,
       DATEDIFF(DAY, fo.order_estimated_delivery_date, fo.order_delivered_customer_date) AS delay_days,
       CASE WHEN fo.order_delivered_customer_date IS NULL THEN 'Undelivered' WHEN fo.order_delivered_customer_date > fo.order_estimated_delivery_date THEN 'Delayed' ELSE 'On Time' END AS delivery_status,
       COALESCE (oi.total_order_value, 0) AS total_order_value,
       COALESCE (oi.total_freight_value, 0) AS total_freight_value,
       COALESCE (oi.total_item_count, 0) AS total_item_count,
       r.avg_review_score
FROM   fact_orders AS fo
       INNER JOIN
       dim_customers AS c
       ON fo.customer_id = c.customer_id
       LEFT OUTER JOIN
       OrderItemsAgg AS oi
       ON fo.order_id = oi.order_id
       LEFT OUTER JOIN
       OrderReviewsAgg AS r
       ON fo.order_id = r.order_id
WHERE  fo.order_status = 'delivered';