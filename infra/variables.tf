variable "pandas_layer_arn" {
  description = "ARN of the AWS SDK for pandas layer (pandas + pyarrow) for this region/Python version"
  type        = string
  default     = "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python312:24"
}