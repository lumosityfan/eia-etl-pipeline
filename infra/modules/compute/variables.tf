variable "eia_secret_arn" {
    description = "ARN of the Secrets Manager secret holding the EIA API key"
    type        = string
}

variable "raw_bucket_name" {
    description = "Name of the S3 bucket for raw EIA data"
    type        = string
}

variable "extract_lambda_role_arn" {
    description = "ARN of the extract lambda role in IAM"
    type        = string
}

variable "processed_bucket_name" {
    type = string
}

variable "transform_lambda_role_arn" {
    type = string
}

variable "pandas_layer_arn" {
    description = "ARN of the AWS SDK for pandas layer (pandas + pyarrow) for this region/Python version"
    type        = string
}

variable "load_lambda_role_arn" {
    type = string
}

variable "db_host" {
    type = string
}

variable "db_name" {
    type = string
}