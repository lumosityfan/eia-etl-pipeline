import os
import io
import json
from datetime import datetime, timezone

import boto3
import pandas as pd

s3 = boto3.client("s3")


def find_latest_raw_key(bucket: str) -> str:
    """No event-driven trigger yet, so default to the most recently written raw object."""
    paginator = s3.get_paginator("list_objects_v2")
    latest = None
    for page in paginator.paginate(Bucket=bucket, Prefix="raw/"):
        for obj in page.get("Contents", []):
            if latest is None or obj["LastModified"] > latest["LastModified"]:
                latest = obj
    if latest is None:
        raise RuntimeError(f"No objects found under s3://{bucket}/raw/")
    return latest["Key"]


def load_raw_rows(bucket: str, key: str) -> list[dict]:
    obj = s3.get_object(Bucket=bucket, Key=key)
    return json.loads(obj["Body"].read())["rows"]


def transform(rows: list[dict]) -> pd.DataFrame:
    df = pd.DataFrame(rows)

    df["value"] = pd.to_numeric(df["value"], errors="coerce")
    df["period"] = pd.to_datetime(df["period"], format="%Y-%m-%dT%H", utc=True)

    before = len(df)
    df = df.dropna(subset=["value", "period", "respondent", "type"])
    if (dropped := before - len(df)):
        print(f"Dropped {dropped} rows with missing/invalid value, period, respondent, or type")

    # One row per (period, respondent) with actual demand and forecast as
    # separate columns, so forecast error can be computed directly.
    pivoted = df.pivot_table(
        index=["period", "respondent", "respondent-name"],
        columns="type",
        values="value",
        aggfunc="first",
    ).reset_index()
    pivoted.columns.name = None
    pivoted = pivoted.rename(columns={"D": "demand_actual_mwh", "DF": "demand_forecast_mwh"})

    if "demand_actual_mwh" in pivoted and "demand_forecast_mwh" in pivoted:
        pivoted["forecast_error_mwh"] = pivoted["demand_forecast_mwh"] - pivoted["demand_actual_mwh"]

    return pivoted


def write_processed_to_s3(df: pd.DataFrame, bucket: str) -> str:
    now = datetime.now(timezone.utc)
    key = f"processed/dt={now.date().isoformat()}/eia_region_demand_{now.strftime('%H%M%S')}.parquet"
    buffer = io.BytesIO()
    df.to_parquet(buffer, index=False)
    s3.put_object(Bucket=bucket, Key=key, Body=buffer.getvalue())
    return key


def lambda_handler(event, context):
    raw_bucket = os.environ["RAW_BUCKET"]
    processed_bucket = os.environ["PROCESSED_BUCKET"]

    raw_key = event.get("s3_key") or find_latest_raw_key(raw_bucket)
    print(f"Transforming s3://{raw_bucket}/{raw_key}")

    rows = load_raw_rows(raw_bucket, raw_key)
    df = transform(rows)
    processed_key = write_processed_to_s3(df, processed_bucket)

    print(f"Wrote {len(df)} rows to s3://{processed_bucket}/{processed_key}")
    return {"row_count": len(df), "s3_key": processed_key}