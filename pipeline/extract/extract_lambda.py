import os
import json
import time
from datetime import datetime, timezone
from functools import lru_cache

import boto3
import urllib3

secretsmanager = boto3.client("secretsmanager")
s3 = boto3.client("s3")
http = urllib3.PoolManager()

EIA_BASE_URL = "https://api.eia.gov/v2/electricity/rto/region-data/data/"
PAGE_LENGTH = 500  # plenty for a handful of respondents over the last day or two

# Respondent (balancing authority) codes to pull. Add more by picking regions at
# https://www.eia.gov/opendata/browser/electricity/rto/region-data and copying
# the facets[respondent][] value(s) it generates.
# Also grabs demand "type" codes to pull.
RESPONDENTS = os.environ.get("EIA_RESPONDENTS", "NY").split(",")
TYPES = os.environ.get("EIA_TYPES", "D,DF").split(",") # D = actual demand, DF = day-ahead forecast

@lru_cache(maxsize=1)
def get_eia_api_key() -> str:
    secret_arn = os.environ["EIA_API_KEY_SECRET_ARN"]
    response = secretsmanager.get_secret_value(SecretId=secret_arn)
    return response["SecretString"]


def fetch_eia_region_data(api_key: str) -> list[dict]:
    """Pull the most recent hourly region records for the configured respondents.

    No start/end filter on purpose: EIA's hourly data has a reporting lag, so
    sorting descending and taking the newest available rows is more reliable
    than assuming a fixed date (like "yesterday") has already been published.
    """
    params = [
        ("api_key", api_key),
        ("frequency", "hourly"),
        ("data[0]", "value"),
        ("sort[0][column]", "period"),
        ("sort[0][direction]", "desc"),
        ("offset", "0"),
        ("length", str(PAGE_LENGTH)),
    ]
    for respondent in RESPONDENTS:
        params.append(("facets[respondent][]", respondent))
    for type_code in TYPES:
        params.append(("facets[type][]", type_code))

    response = _get_with_retries(EIA_BASE_URL, params)
    payload = json.loads(response.data.decode("utf-8"))

    if "error" in payload:
        raise RuntimeError(f"EIA API error: {payload['error']}")

    return payload["response"]["data"]


def _get_with_retries(url, params, max_attempts=3):
    last_error = None
    for attempt in range(1, max_attempts + 1):
        try:
            response = http.request(
                "GET", url, fields=params,
                timeout=urllib3.Timeout(connect=5, read=10),
            )
        except urllib3.exceptions.HTTPError as exc:
            print(f"Attempt {attempt}: request failed: {exc}")
            last_error = str(exc)
            time.sleep(2 ** attempt)  # 2s, 4s, 8s
            continue

        print(f"Attempt {attempt}: EIA API returned HTTP {response.status}")
        if response.status == 200:
            return response

        last_error = f"EIA API returned HTTP {response.status}: {response.data[:300]}"
        time.sleep(2 ** attempt)
    raise RuntimeError(last_error)


def write_raw_to_s3(rows: list[dict]) -> str:
    bucket = os.environ["RAW_BUCKET"]
    extracted_at = datetime.now(timezone.utc)
    key = f"raw/dt={extracted_at.date().isoformat()}/eia_region_data_{extracted_at.strftime('%H%M%S')}.json"
    body = json.dumps({"extracted_at": extracted_at.isoformat(), "rows": rows})
    s3.put_object(Bucket=bucket, Key=key, Body=body.encode("utf-8"), ContentType="application/json")
    return key


def lambda_handler(event, context):
    api_key = get_eia_api_key()
    rows = fetch_eia_region_data(api_key)
    s3_key = write_raw_to_s3(rows)

    print(f"Wrote {len(rows)} rows to s3://{os.environ['RAW_BUCKET']}/{s3_key}")
    return {"row_count": len(rows), "s3_key": s3_key}