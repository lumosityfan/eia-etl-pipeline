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