# Module 7: Intelligent Document Processing Pipeline

## Architecture First

Before writing a single `.tf` file, map the infra. Here is what you are building and why each piece exists:

```text
PDF uploaded to S3
       |
       v
S3 EventBridge notification
       |
       v
EventBridge Rule  -->  Step Functions State Machine
                              |
                    +---------+---------+
                    |                   |
              Step 1: Lambda       (on failure)
              (extract text        --> Catch state
               via Textract)            --> DDB error record
                    |
              Step 2: Lambda
              (analyze text
               via Bedrock/Claude)
                    |
              Step 3: Lambda
              (write result
               to DynamoDB)
                    |
                  DONE
```

### Why EventBridge instead of direct S3 -> Step Functions?

S3 does not trigger Step Functions directly. The pattern is: enable S3 EventBridge notifications on your bucket, then create an EventBridge rule that watches for Object Created events from that bucket and targets the state machine.

### Why Step Functions instead of one big Lambda?

Step Functions lets each stage fail, retry, and report independently. If text extraction succeeds but AI analysis fails, you retry only the analysis step — not the whole pipeline.

It is important to note that the Step Functions IAM role and each Lambda IAM role are separate. The state machine needs `lambda:InvokeFunction` permission, while each Lambda runs under its own role with its own permissions.

## File Structure

```text
doc-processor/
  main.tf
  variables.tf
  outputs.tf
  iam.tf
  lambdas.tf
  stepfunctions.tf
  eventbridge.tf
  terraform.tfvars.example
  lambda/
    extract/
      handler.py
    analyze/
      handler.py
    store/
      handler.py
```

## Step 1: Core Storage Resources

Start with `main.tf`. This sets up the S3 bucket (with EventBridge enabled) and the DynamoDB table.

```hcl
resource "aws_s3_bucket" "pdf_input" {
  bucket = var.input_bucket_name
}

resource "aws_s3_bucket_notification" "pdf_input_eventbridge" {
  bucket      = aws_s3_bucket.pdf_input.id
  eventbridge = true
}

resource "aws_dynamodb_table" "results" {
  name         = var.results_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }
}
```

### Test

```bash
terraform init
terraform plan
```

You should see bucket, bucket notification, and DDB table in the plan.

## Step 2: Lambda Functions (the workers)

`lambdas.tf` packages three local Python handlers with `archive_file`, then defines three Lambda functions:

- `extract`: Textract stage
- `analyze`: Bedrock/Claude stage
- `store`: DynamoDB persistence stage

Handler stubs exist in:

- `lambda/extract/handler.py`
- `lambda/analyze/handler.py`
- `lambda/store/handler.py`

### Test

```bash
terraform plan
```

If packaging paths are valid, plan runs without source file errors.

## Step 3: IAM Roles and Policies

`iam.tf` creates three trust boundaries:

1. **Lambda execution role** for worker Lambdas
2. **Step Functions execution role** that can invoke Lambdas (+ write execution logs)
3. **EventBridge role** that can call `states:StartExecution`

At runtime, nearly all AccessDenied failures are policy issues in this file.

### Test

```bash
terraform validate
```

## Step 4: State Machine Definition

`stepfunctions.tf` defines:

- `ExtractText`
- `AnalyzeText`
- `StoreResults`
- `RecordFailure`
- `ProcessingFailed`

Key implementation details:

- Uses `arn:aws:states:::lambda:invoke` integration pattern
- Uses `Retry` blocks with exponential backoff
- Uses `Catch` blocks to route failures into `RecordFailure`
- Writes Step Functions execution logs to CloudWatch

### Test

```bash
terraform apply
```

Then verify the state machine graph in the Step Functions console.

## Step 5: EventBridge Rule (the trigger)

`eventbridge.tf` connects S3 uploads to the state machine:

- Event pattern filters to your bucket
- Key suffix filter only allows `.pdf`
- Target is the state machine ARN

### Test (end-to-end)

```bash
terraform apply
aws s3 cp test.pdf s3://<your-input-bucket-name>/
```

Within seconds, a new execution should appear in Step Functions.

## Step 6: Variables and Outputs

Variables include:

- `region`
- `project_name`
- `input_bucket_name`
- `results_table_name`

Outputs include:

- `input_bucket`
- `results_table`
- `state_machine_arn`
- `event_rule_name`

## Key Concepts Introduced in This Module

| Concept | What you learned |
| --- | --- |
| `aws_s3_bucket_notification` with `eventbridge = true` | How to forward S3 events to EventBridge |
| `aws_cloudwatch_event_rule` + `event_pattern` | How to filter S3 events by bucket and key suffix |
| `aws_cloudwatch_event_target` | How to route a matching event to a Step Functions execution |
| `aws_sfn_state_machine` with `jsonencode` | How to define ASL state machine logic inside Terraform |
| `Retry` and `Catch` in ASL | Per-step retry with exponential backoff and failure routing |
| Separate IAM roles per service | Lambda role, SFN role, EventBridge role with least privilege boundaries |

## What to Replace the Stubs With

When making this production-ready:

- **extract**: `boto3.client("textract").detect_document_text(...)`
- **analyze**: `boto3.client("bedrock-runtime").invoke_model(...)`
- **store**: Keep as-is, but evolve DynamoDB item schema to your analysis payload

## Brief Manual QA

1. Upload a `.pdf`; verify a new Step Functions execution starts.
2. Confirm execution reaches `StoreResults` in success path.
3. Query DynamoDB and confirm item exists with `document_id` and `status`.
4. Simulate failure in `analyze`; verify `RecordFailure` writes error payload with `status = FAILED`.
