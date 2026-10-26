CREATE DATABASE olist_ecommerce;


GO
USE olist_ecommerce;


GO
-- Dim Category Translation --
IF OBJECT_ID('dim_category_translation', 'U') IS NULL
    CREATE TABLE dim_category_translation (
        product_category_name         NVARCHAR (100) PRIMARY KEY,
        product_category_name_english NVARCHAR (100)
    );

-- Dim Customers --
IF OBJECT_ID('dim_customers', 'U') IS NULL
    CREATE TABLE dim_customers (
        customer_id              VARCHAR (50)  PRIMARY KEY,
        customer_unique_id       VARCHAR (50)  NOT NULL,
        customer_zip_code_prefix VARCHAR (10) ,
        customer_city            VARCHAR (100),
        customer_state           VARCHAR (5)  
    );

-- Dim Products --
IF OBJECT_ID('dim_products', 'U') IS NULL
    CREATE TABLE dim_products (
        product_id                 VARCHAR (50)   PRIMARY KEY,
        product_category_name      NVARCHAR (100),
        product_name_lenght        INT           ,
        product_description_lenght INT           ,
        product_photos_qty         INT           ,
        product_weight_g           FLOAT         ,
        product_length_cm          FLOAT         ,
        product_height_cm          FLOAT         ,
        product_width_cm           FLOAT         
    );

-- Dim Sellers --
IF OBJECT_ID('dim_sellers', 'U') IS NULL
    CREATE TABLE dim_sellers (
        seller_id              VARCHAR (50)  PRIMARY KEY,
        seller_zip_code_prefix VARCHAR (10) ,
        seller_city            VARCHAR (100),
        seller_state           VARCHAR (5)  
    );

-- Dim Geolocation --
IF OBJECT_ID('dim_geolocation', 'U') IS NULL
    CREATE TABLE dim_geolocation (
        geolocation_zip_code_prefix VARCHAR (10)  ,
        geolocation_lat             FLOAT         ,
        geolocation_lng             FLOAT         ,
        geolocation_city            NVARCHAR (100),
        geolocation_state           VARCHAR (5)   
    );

-- Fact Orders --
IF OBJECT_ID('fact_orders', 'U') IS NULL
    CREATE TABLE fact_orders (
        order_id                      VARCHAR (50) PRIMARY KEY,
        customer_id                   VARCHAR (50) FOREIGN KEY REFERENCES dim_customers (customer_id),
        order_status                  VARCHAR (30),
        order_purchase_timestamp      DATETIME2    NOT NULL,
        order_approved_at             DATETIME2   ,
        order_delivered_carrier_date  DATETIME2   ,
        order_delivered_customer_date DATETIME2   ,
        order_estimated_delivery_date DATETIME2   
    );

-- Fact Order Items --
IF OBJECT_ID('fact_order_items', 'U') IS NULL
    CREATE TABLE fact_order_items (
        order_id            VARCHAR (50)    FOREIGN KEY REFERENCES fact_orders (order_id),
        order_item_id       INT            ,
        product_id          VARCHAR (50)    FOREIGN KEY REFERENCES dim_products (product_id),
        seller_id           VARCHAR (50)    FOREIGN KEY REFERENCES dim_sellers (seller_id),
        shipping_limit_date DATETIME2      ,
        price               DECIMAL (10, 2) NOT NULL,
        freight_value       DECIMAL (10, 2) NOT NULL,
        CONSTRAINT PK_order_items PRIMARY KEY (order_id, order_item_id)
    );

-- Fact Order Payments --
IF OBJECT_ID('fact_order_payments', 'U') IS NULL
    CREATE TABLE fact_order_payments (
        order_id             VARCHAR (50)    FOREIGN KEY REFERENCES fact_orders (order_id),
        payment_sequential   INT            ,
        payment_type         VARCHAR (30)   ,
        payment_installments INT            ,
        payment_value        DECIMAL (10, 2) NOT NULL,
        CONSTRAINT PK_order_payments PRIMARY KEY (order_id, payment_sequential)
    );

-- Fact Order Reviews --
IF OBJECT_ID('fact_order_reviews', 'U') IS NULL
    CREATE TABLE fact_order_reviews (
        review_id               VARCHAR (50)  ,
        order_id                VARCHAR (50)   FOREIGN KEY REFERENCES fact_orders (order_id),
        review_score            INT           ,
        review_comment_title    NVARCHAR (255),
        review_comment_message  NVARCHAR (MAX),
        review_creation_date    DATETIME2     ,
        review_answer_timestamp DATETIME2     ,
        CONSTRAINT PK_order_reviews PRIMARY KEY (review_id, order_id)
    );

-- B-Tree Indexes --
CREATE NONCLUSTERED INDEX idx_orders_customer
    ON fact_orders(customer_id);

CREATE NONCLUSTERED INDEX idx_orders_timestamp
    ON fact_orders(order_purchase_timestamp);

CREATE NONCLUSTERED INDEX idx_items_product
    ON fact_order_items(product_id);

CREATE NONCLUSTERED INDEX idx_items_seller
    ON fact_order_items(seller_id);

CREATE NONCLUSTERED INDEX idx_reviews_order
    ON fact_order_reviews(order_id);

CREATE NONCLUSTERED INDEX idx_geo_zip
    ON dim_geolocation(geolocation_zip_code_prefix);


