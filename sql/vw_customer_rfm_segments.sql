USE olist_ecommerce;


GO
CREATE OR ALTER VIEW vw_customer_rfm_segments
AS
WITH   BaseMetrics
AS     (SELECT   c.customer_unique_id,
                 DATEDIFF(DAY, MAX(fo.order_purchase_timestamp), CAST ('2018-09-03' AS DATETIME2)) AS recency,
                 COUNT(DISTINCT fo.order_id) AS frequency,
                 SUM(oi.price) AS monetary
        FROM     dim_customers AS c
                 INNER JOIN
                 fact_orders AS fo
                 ON c.customer_id = fo.customer_id
                 INNER JOIN
                 fact_order_items AS oi
                 ON fo.order_id = oi.order_id
        WHERE    fo.order_status = 'delivered'
        GROUP BY c.customer_unique_id),
       RFMScores
AS     (SELECT customer_unique_id,
               recency,
               frequency,
               monetary,
               NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
               NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
               NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
        FROM   BaseMetrics),
       Segmented
AS     (SELECT customer_unique_id,
               recency,
               frequency,
               monetary,
               r_score,
               f_score,
               m_score,
               CAST (r_score AS VARCHAR (1)) + CAST (f_score AS VARCHAR (1)) + CAST (m_score AS VARCHAR (1)) AS rfm_cell
        FROM   RFMScores)
SELECT customer_unique_id,
       recency,
       frequency,
       monetary,
       r_score,
       f_score,
       m_score,
       rfm_cell,
       CASE WHEN r_score >= 4
                 AND f_score >= 4
                 AND m_score >= 4 THEN 'Champions' WHEN r_score >= 3
                                                        AND f_score >= 3 THEN 'Loyal Customers' WHEN r_score >= 4
                                                                                                     AND f_score <= 2 THEN 'Recent Customers' WHEN r_score <= 2
                                                                                                                                                   AND f_score >= 3 THEN 'At Risk' WHEN r_score = 1
                                                                                                                                                                                        AND f_score = 1 THEN 'Lost Customers' ELSE 'Potential / Standard' END AS customer_segment
FROM   Segmented;

