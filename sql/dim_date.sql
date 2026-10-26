USE olist_ecommerce;


GO
IF OBJECT_ID('dim_date', 'U') IS NULL
    CREATE TABLE dim_date (
        date_key     INT           PRIMARY KEY,
        full_date    DATE          NOT NULL,
        year         INT           NOT NULL,
        quarter      INT           NOT NULL,
        quarter_name VARCHAR (20)  NOT NULL,
        month        INT           NOT NULL,
        month_name   NVARCHAR (20) NOT NULL,
        month_year   VARCHAR (10)  NOT NULL,
        day_of_week  INT           NOT NULL,
        day_of_month INT           NOT NULL,
        day_name     NVARCHAR (20) NOT NULL,
        is_weekend   BIT           NOT NULL
    );

WITH DateCTE
AS   (SELECT CAST ('2016-01-01' AS DATE) AS CalendarDate
      UNION ALL
      SELECT DATEADD(DAY, 1, CalendarDate)
      FROM   DateCTE
      WHERE  CalendarDate < '2018-12-31')
INSERT INTO dim_date (
    date_key,
    full_date,
    year,
    quarter,
    quarter_name,
    month,
    month_name,
    month_year,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend
)
SELECT CAST (CONVERT (VARCHAR (8), CalendarDate, 112) AS INT) AS date_key,
       CalendarDate AS full_date,
       DATEPART(YEAR, CalendarDate) AS year,
       DATEPART(QUARTER, CalendarDate) AS quarter,
       'Q' + CAST (DATEPART(QUARTER, CalendarDate) AS VARCHAR (1)) AS quarter_name,
       DATEPART(MONTH, CalendarDate) AS month,
       DATENAME(MONTH, CalendarDate) AS month_name,
       CONVERT (VARCHAR (7), CalendarDate, 120) AS month_year,
       DATEPART(DAY, CalendarDate) AS day_of_month,
       DATEPART(WEEKDAY, CalendarDate) AS day_of_week,
       DATENAME(WEEKDAY, CalendarDate) AS day_name,
       CASE WHEN DATEPART(WEEKDAY, CalendarDate) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM   DateCTE
OPTION (MAXRECURSION 1500);