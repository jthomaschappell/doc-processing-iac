# Package each Lambda from local source
data "archive_file" "extract" {
  type        = "zip"
  source_file = "${path.module}/lambda/extract/handler.py"
  output_path = "${path.module}/lambda/extract.zip"
}

data "archive_file" "analyze" {
  type        = "zip"
  source_file = "${path.module}/lambda/analyze/handler.py"
  output_path = "${path.module}/lambda/analyze.zip"
}

data "archive_file" "store" {
  type        = "zip"
  source_file = "${path.module}/lambda/store/handler.py"
  output_path = "${path.module}/lambda/store.zip"
}

# Shared, deterministic naming prefix to avoid collisions
locals {
  name_prefix = "${var.project_name}-doc"
}

# Step 1 Lambda: Extract text from PDF via Textract
resource "aws_lambda_function" "extract" {
  function_name    = "${local.name_prefix}-extract"
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.extract.output_path
  source_code_hash = data.archive_file.extract.output_base64sha256
  timeout          = 300
  memory_size      = 512

  environment {
    variables = {
      INPUT_BUCKET = aws_s3_bucket.pdf_input.id
    }
  }
}

# Step 2 Lambda: Send extracted text to Bedrock for analysis
resource "aws_lambda_function" "analyze" {
  function_name    = "${local.name_prefix}-analyze"
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.analyze.output_path
  source_code_hash = data.archive_file.analyze.output_base64sha256
  timeout          = 300
  memory_size      = 512
}

# Step 3 Lambda: Write results to DynamoDB
resource "aws_lambda_function" "store" {
  function_name    = "${local.name_prefix}-store"
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  role             = aws_iam_role.lambda_exec.arn
  filename         = data.archive_file.store.output_path
  source_code_hash = data.archive_file.store.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      RESULTS_TABLE = aws_dynamodb_table.results.name
    }
  }
}
