resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/states/${var.project_name}-doc-processor"
  retention_in_days = 14
}

resource "aws_sfn_state_machine" "doc_processor" {
  name     = "${var.project_name}-doc-processor"
  role_arn = aws_iam_role.sfn_exec.arn

  # The definition is written in Amazon States Language (ASL).
  # jsonencode() converts HCL maps to valid JSON at apply time,
  # which lets you reference other Terraform resources by ARN directly.
  definition = jsonencode({
    Comment = "PDF extraction and AI analysis pipeline"
    StartAt = "ExtractText"

    States = {
      ExtractText = {
        Type     = "Task"
        Resource = aws_lambda_function.extract.arn
        Next       = "AnalyzeText"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "RecordFailure"
          ResultPath  = "$.error"
        }]
      }

      AnalyzeText = {
        Type     = "Task"
        Resource = aws_lambda_function.analyze.arn
        Next       = "StoreResults"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException"]
          IntervalSeconds = 5
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "RecordFailure"
          ResultPath  = "$.error"
        }]
      }

      StoreResults = {
        Type     = "Task"
        Resource = aws_lambda_function.store.arn
        End        = true
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2.0
        }]
      }

      RecordFailure = {
        Type     = "Task"
        Resource = aws_lambda_function.store.arn
        Next       = "ProcessingFailed"
      }

      ProcessingFailed = {
        Type  = "Fail"
        Error = "DocumentProcessingFailed"
        Cause = "One or more pipeline stages failed after retries"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tags = {
    Name = "${var.project_name}-doc-processor"
  }
}
