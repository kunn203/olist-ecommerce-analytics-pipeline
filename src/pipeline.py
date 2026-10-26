import os
import urllib
import logging
import pandas as pd
from sqlalchemy import create_engine

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

Connection_String = (
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=localhost\\SQLEXPRESS ;"
    "Database=olist_ecommerce;"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)

params = urllib.parse.quote_plus(Connection_String)
database_url = f"mssql+pyodbc:///?odbc_connect={params}"

class OlistETL:
    def __init__(self, data_dir: str, engine):
        self.data_dir = data_dir
        self.engine = engine

    def _read_csv(self, filename: str) -> pd.DataFrame:
        path = os.path.join(self.data_dir, filename)
        if not os.path.exists(path):
            raise FileNotFoundError(f"Không tìm thấy file: {path}")
        return pd.read_csv(path, encoding="utf-8")

    def process_translations(self) -> pd.DataFrame:
        logging.info("Đang xử lý Danh mục dịch")
        df = self._read_csv("product_category_name_translation.csv")
        return df.drop_duplicates(subset=["product_category_name"])

    def process_customers(self) -> pd.DataFrame:
        logging.info("Đang xử lý Customers...")
        df = self._read_csv("olist_customers_dataset.csv")
        df["customer_city"] = df["customer_city"].astype(str).str.strip().str.title()
        df["customer_state"] = df["customer_state"].astype(str).str.strip().str.upper()
        return df.drop_duplicates(subset=["customer_id"])

    def process_products(self) -> pd.DataFrame:
        logging.info("Đang xử lý Products...")
        df = self._read_csv("olist_products_dataset.csv")
        df["product_category_name"] = df["product_category_name"].fillna("unknown")
        numeric_cols = [
            "product_name_lenght", "product_description_lenght", 
            "product_photos_qty", "product_weight_g", 
            "product_length_cm", "product_height_cm", "product_width_cm"
        ]
        df[numeric_cols] = df[numeric_cols].fillna(0)
        return df.drop_duplicates(subset=["product_id"])

    def process_sellers(self) -> pd.DataFrame:
        logging.info("Đang xử lý Sellers...")
        df = self._read_csv("olist_sellers_dataset.csv")
        df["seller_city"] = df["seller_city"].astype(str).str.strip().str.title()
        df["seller_state"] = df["seller_state"].astype(str).str.strip().str.upper()
        return df.drop_duplicates(subset=["seller_id"])

    def process_geolocation(self) -> pd.DataFrame:
        logging.info("Đang xử lý Geolocation...")
        df = self._read_csv("olist_geolocation_dataset.csv")
        # Khử trùng lặp 
        return df.drop_duplicates(subset=[
            "geolocation_zip_code_prefix", "geolocation_lat", 
            "geolocation_lng", "geolocation_city", "geolocation_state"
        ])

    def process_orders(self) -> pd.DataFrame:
        logging.info("Đang xử lý Orders...")
        df = self._read_csv("olist_orders_dataset.csv")
        date_cols = [
            "order_purchase_timestamp", "order_approved_at",
            "order_delivered_carrier_date", "order_delivered_customer_date",
            "order_estimated_delivery_date"
        ]
        for col in date_cols:
            df[col] = pd.to_datetime(df[col], errors="coerce")
        return df.dropna(subset=["order_purchase_timestamp"]).drop_duplicates(subset=["order_id"])

    def process_order_items(self) -> pd.DataFrame:
        logging.info("Đang xử lý Order Items...")
        df = self._read_csv("olist_order_items_dataset.csv")
        df["shipping_limit_date"] = pd.to_datetime(df["shipping_limit_date"], errors="coerce")
        df = df[(df["price"] >= 0) & (df["freight_value"] >= 0)]
        return df.drop_duplicates(subset=["order_id", "order_item_id"])

    def process_payments(self) -> pd.DataFrame:
        logging.info("Đang xử lý Payments...")
        df = self._read_csv("olist_order_payments_dataset.csv")
        df = df[df["payment_value"] >= 0]
        return df.drop_duplicates(subset=["order_id", "payment_sequential"])

    def process_reviews(self, valid_order_ids: set) -> pd.DataFrame:
        logging.info("Đang xử lý Reviews...")
        df = self._read_csv("olist_order_reviews_dataset.csv")
        df["review_creation_date"] = pd.to_datetime(df["review_creation_date"], errors="coerce")
        df["review_answer_timestamp"] = pd.to_datetime(df["review_answer_timestamp"], errors="coerce")
        
        df = df[df["order_id"].isin(valid_order_ids)]
        return df.drop_duplicates(subset=["review_id", "order_id"])

    def load(self, df: pd.DataFrame, table_name: str, chunksize: int = 10000):
        logging.info(f"Đang ghi {len(df):,} dòng vào [{table_name}]...")
        df.to_sql(
            name=table_name,
            con=self.engine,
            if_exists="append",
            index=False,
            chunksize=chunksize
        )
        logging.info(f"Đã lưu thành công [{table_name}].")

    def run_all(self):
        # Load Dimensions   
        self.load(self.process_translations(), "dim_category_translation")
        self.load(self.process_customers(), "dim_customers")
        self.load(self.process_products(), "dim_products")
        self.load(self.process_sellers(), "dim_sellers")
        self.load(self.process_geolocation(), "dim_geolocation")

        # Load Fact Orders
        orders_df = self.process_orders()
        self.load(orders_df, "fact_orders")

        # Load các Fact phụ thuộc vào fact_orders
        self.load(self.process_order_items(), "fact_order_items")
        self.load(self.process_payments(), "fact_order_payments")
        
        valid_orders = set(orders_df["order_id"].unique())
        self.load(self.process_reviews(valid_orders), "fact_order_reviews")

        logging.info("Đã lưu thành công vào SQL Server.")

if __name__ == "__main__":
    data_dir = "./data"
    engine = create_engine(database_url, fast_executemany=True)
    
    pipeline = OlistETL(data_dir=data_dir, engine=engine)
    pipeline.run_all()