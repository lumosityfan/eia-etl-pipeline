import json
from datetime import datetime, timedelta

import boto3
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.amazon.aws.operators.lambda_function import LambdaInvokeFunctionOperator

AWS_REGION = "us-east-1"


def notify_airflow_failure(context):
    import os
    topic_arn = os.environ.get("SNS_TOPIC_ARN")
    if not topic_arn:
        return
    task_id = context["task_instance"].task_id
    dag_id = context["dag"].dag_id
    sns = boto3.client("sns", region_name=AWS_REGION)
    sns.publish(
        TopicArn=topic_arn,
        Subject=f"Airflow task failed: {dag_id}.{task_id}"[:100],
        Message=f"DAG: {dag_id}\nTask: {task_id}\nError: {context.get('exception')}",
    )


default_args = {
    "owner": "jeff",
    "retries": 2,
    "retry_delay": timedelta(minutes=2),
    "on_failure_callback": notify_airflow_failure,
}


def _parse_lambda_payload(ti, task_id):
    payload = json.loads(ti.xcom_pull(task_ids=task_id))
    if payload.get("row_count") == 0:
        raise ValueError(f"{task_id} returned zero rows: {payload}")
    return payload["s3_key"]


def validate_raw(**context):
    return _parse_lambda_payload(context["ti"], "extract_task")


def validate_transform(**context):
    return _parse_lambda_payload(context["ti"], "transform_task")


with DAG(
    dag_id="eia_pipeline_dag",
    default_args=default_args,
    schedule="@daily",
    start_date=datetime(2026, 11, 1),
    catchup=False,
    max_active_runs=1,
    tags=["eia-etl"],
) as dag:

    extract_task = LambdaInvokeFunctionOperator(
        task_id="extract_task",
        function_name="extract-lambda",
        region_name=AWS_REGION,
    )

    validate_raw_task = PythonOperator(
        task_id="validate_raw_task",
        python_callable=validate_raw,
    )

    transform_task = LambdaInvokeFunctionOperator(
        task_id="transform_task",
        function_name="transform-lambda",
        region_name=AWS_REGION,
        payload=json.dumps({"s3_key": "{{ ti.xcom_pull(task_ids='validate_raw_task') }}"}),
    )

    validate_transform_task = PythonOperator(
        task_id="validate_transform_task",
        python_callable=validate_transform,
    )

    load_task = LambdaInvokeFunctionOperator(
        task_id="load_task",
        function_name="load-lambda",
        region_name=AWS_REGION,
        payload=json.dumps({"s3_key": "{{ ti.xcom_pull(task_ids='validate_transform_task') }}"}),
    )

    extract_task >> validate_raw_task >> transform_task >> validate_transform_task >> load_task