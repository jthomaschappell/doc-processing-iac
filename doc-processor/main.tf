terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# --- S3 bucket for incoming PDFs ---
resource "aws_s3_bucket" "pdf_input" {
  bucket = var.input_bucket_name

  tags = {
    Name = "pdf-input"
  }
}

# CRITICAL: this setting tells S3 to forward ALL events to EventBridge.
# Without this, your EventBridge rule will never fire.
resource "aws_s3_bucket_notification" "pdf_input_eventbridge" {
  bucket      = aws_s3_bucket.pdf_input.id
  eventbridge = true
}

# --- DynamoDB table for analysis results ---
resource "aws_dynamodb_table" "results" {
  name         = var.results_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }

  tags = {
    Name = "doc-processing-results"
  }
}
