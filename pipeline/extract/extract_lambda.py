import os
import boto3
from functools import lru_cache

secretsmanager = boto3.client("secretsmanager")

@lru_cache(maxsize=1)
def get_eia_api_key() -> str:
    secret_arn = os.environ["EIA_API_KEY_SECRET_ARN"]
    response = secretsmanager.get_secret_value(SecretId=secret_arn)
    return response["SecretString"]

def lambda_handler(event, context):
    api_key = get_eia_api_key()
    print(f"Loaded API key, length={len(api_key)}")