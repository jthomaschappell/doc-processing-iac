variable "region" {
  type        = string
  description = "AWS region to deploy resources into"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Prefix used for naming resources"
  default     = "crash-course"
}

variable "input_bucket_name" {
  type        = string
  description = "Globally unique name for the PDF input bucket"
}

variable "results_table_name" {
  type        = string
  description = "DynamoDB table name for results"
  default     = "doc-processing-results"
}
