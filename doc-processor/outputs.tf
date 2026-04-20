output "input_bucket" {
  description = "S3 bucket receiving PDF uploads"
  value       = aws_s3_bucket.pdf_input.id
}

output "results_table" {
  description = "DynamoDB table storing processing output"
  value       = aws_dynamodb_table.results.name
}

output "state_machine_arn" {
  description = "Step Functions state machine ARN"
  value       = aws_sfn_state_machine.doc_processor.arn
}

output "event_rule_name" {
  description = "EventBridge rule watching PDF uploads"
  value       = aws_cloudwatch_event_rule.s3_pdf_uploaded.name
}
