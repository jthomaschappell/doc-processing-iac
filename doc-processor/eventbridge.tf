resource "aws_cloudwatch_event_rule" "s3_pdf_uploaded" {
  name        = "${var.project_name}-pdf-uploaded"
  description = "Fires when a .pdf is uploaded to the input bucket"

  # This event pattern matches S3 Object Created events from the specific bucket,
  # filtered to only .pdf files by key suffix.
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.pdf_input.id]
      }
      object = {
        key = [{ suffix = ".pdf" }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "start_sfn" {
  rule      = aws_cloudwatch_event_rule.s3_pdf_uploaded.name
  target_id = "StartDocProcessor"
  arn       = aws_sfn_state_machine.doc_processor.arn
  role_arn  = aws_iam_role.eventbridge_sfn.arn
}
