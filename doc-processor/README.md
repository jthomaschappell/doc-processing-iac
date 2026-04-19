# Document Processor Terraform Module

This module provisions an S3 -> EventBridge -> Step Functions -> Lambda -> DynamoDB workflow for PDF processing.

## Quick start

1. Copy the example variables file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Update `input_bucket_name` so it is globally unique.

3. Deploy:

   ```bash
   terraform init
   terraform validate
   terraform plan
   terraform apply
   ```

4. Upload a PDF:

   ```bash
   aws s3 cp test.pdf s3://<your-input-bucket-name>/
   ```

5. Watch Step Functions executions and verify DynamoDB writes.

## Notes

- Lambda handlers are intentionally stubbed for instructional flow.
- Replace extraction logic with Textract API calls and analysis logic with Bedrock model invocation.
