# HUMAN_SETUP_document-processing

Use this checklist to complete the human-only setup steps for Module 7.

## 1) AWS prerequisites

- Ensure you have an AWS account with permissions for S3, Lambda, IAM, Step Functions, EventBridge, CloudWatch Logs, and DynamoDB.
- Configure local credentials (`aws configure` or SSO profile).
- Pick a deployment region that supports your intended Bedrock model.

## 2) Bedrock model access

- In AWS Console, open **Amazon Bedrock**.
- Request or confirm access to your target model (for example Claude Sonnet).
- Note the final `modelId` you will use in `analyze/handler.py`.

## 3) Terraform inputs

- Navigate to `doc-processor/`.
- Copy `terraform.tfvars.example` to `terraform.tfvars`.
- Set `input_bucket_name` to a globally unique value.
- Optionally customize `project_name` and `results_table_name`.

## 4) Deploy infrastructure

Run:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

## 5) Runtime verification permissions

- Confirm your IAM identity can upload to the created bucket.
- Confirm your IAM identity can view Step Functions executions and DynamoDB table rows.

## 6) Optional: production hardening

- Split Lambda roles per function for tighter least-privilege.
- Add dead-letter queue and alarms for failed executions.
- Add KMS encryption policies and lifecycle rules for the bucket.
