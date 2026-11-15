import os
import io

import boto3
import pandas as pd
import pg8000.native

s3 = boto3.client("s3")
rds = boto3.client("rds")
sns = boto3.client("sns")

DB_HOST = os.environ["DB_HOST"]
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ["DB_NAME"]
DB_USER = os.environ["DB_USER"]
AWS_REGION = os.environ["AWS_REGION"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

UPSERT_SQL = """
INSERT INTO demand_readings
    (period, respondent, respondent_name, demand_actual_mwh, demand_forecast_mwh, forecast_error_mwh)
VALUES
    (:period, :respondent, :respondent_name, :demand_actual_mwh, :demand_forecast_mwh, :forecast_error_mwh)
ON CONFLICT (period, respondent) DO UPDATE SET
    respondent_name      = EXCLUDED.respondent_name,
    demand_actual_mwh     = EXCLUDED.demand_actual_mwh,
    demand_forecast_mwh   = EXCLUDED.demand_forecast_mwh,
    forecast_error_mwh    = EXCLUDED.forecast_error_mwh
"""

def publish_notification(status, row_count=None, s3_key=None, error=None):
    lines = [f"Status: {status}"]
    if s3_key:
        lines.append(f"Source file: {s3_key}")
    if row_count is not None:
        lines.append(f"Rows upserted: {row_count}")
    if error:
        lines.append(f"Error: {error}")
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"EIA ETL load step: {status}"[:100],
        Message="\n".join(lines),
    )

def find_latest_processed_key(bucket: str) -> str:
    paginator = s3.get_paginator("list_objects_v2")
    latest = None
    for page in paginator.paginate(Bucket=bucket, Prefix="processed/"):
        for obj in page.get("Contents", []):
            if latest is None or obj["LastModified"] > latest["LastModified"]:
                latest = obj
    if latest is None:
        raise RuntimeError(f"No objects found under s3://{bucket}/processed/")
    return latest["Key"]

def load_processed_df(bucket: str, key: str) -> pd.DataFrame:
    obj = s3.get_object(Bucket=bucket, Key=key)
    return pd.read_parquet(io.BytesIO(obj["Body"].read()))

def get_connection():
    token = rds.generate_db_auth_token(
        DBHostname=DB_HOST, Port=DB_PORT, DBUsername=DB_USER, Region=AWS_REGION,
    )
    return pg8000.native.Connection(
        user=DB_USER, host=DB_HOST, port=DB_PORT, database=DB_NAME,
        password=token, ssl_context=True,
    )

def upsert_rows(conn, df: pd.DataFrame) -> int:
    count = 0
    for row in df.to_dict(orient="records"):
        conn.run(
            UPSERT_SQL,
            period=row["period"].to_pydatetime(),
            respondent=row["respondent"],
            respondent_name=row.get("respondent-name"),
            demand_actual_mwh=None if pd.isna(row.get("demand_actual_mwh")) else float(row["demand_actual_mwh"]),
            demand_forecast_mwh=None if pd.isna(row.get("demand_forecast_mwh")) else float(row["demand_forecast_mwh"]),
            forecast_error_mwh=None if pd.isna(row.get("forecast_error_mwh")) else float(row["forecast_error_mwh"]),
        )
        count += 1
    return count

def lambda_handler(event, context):
    bucket = os.environ["PROCESSED_BUCKET"]
    key = event.get("s3_key") or find_latest_processed_key(bucket)
    print(f"Loading s3://{bucket}/{key}")

    try:
        df = load_processed_df(bucket, key)
        conn = get_connection()
        try:
            row_count = upsert_rows(conn, df)
        finally:
            conn.close()
    except Exception as exc:
        print(f"Load failed: {exc}")
        publish_notification("FAILURE", s3_key=key, error=str(exc))
        raise

    print(f"Upserted {row_count} rows from s3://{bucket}/{key}")
    publish_notification("SUCCESS", row_count=row_count, s3_key=key)
    return {"row_count": row_count, "s3_key": key}