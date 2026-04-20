# Module 7: Intelligent Document Processing Pipeline (Incremental Workflow)

This module uses a strict development loop:

1. **Build** a tiny slice
2. **Validate** with one command
3. **Observe** one concrete signal
4. **Commit** only if green

If a checkpoint fails, fix it before moving forward.

## Target Architecture

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

## Why this trigger pattern?

- S3 cannot directly start Step Functions.
- You must enable S3 -> EventBridge forwarding on the bucket.
- Then create an EventBridge rule targeting the state machine.

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

---

## Milestone 0: Bootstrap Terraform Skeleton

### Build

Create:

- `variables.tf`
- `outputs.tf`
- provider block in `main.tf`
- `terraform.tfvars.example`

### Validate

```bash
terraform init
terraform validate
```

### Observe

- `terraform validate` prints `Success! The configuration is valid.`

### Commit checkpoint

```bash
git add doc-processor/{main.tf,variables.tf,outputs.tf,terraform.tfvars.example}
git commit -m "Bootstrap doc-processor terraform module"
```

### Stop sign

Do not proceed until init and validate are green.

---

## Milestone 1: Add Core Data Plane (S3 + DDB)

### Build

In `main.tf`, add:

- `aws_s3_bucket.pdf_input`
- `aws_s3_bucket_notification.pdf_input_eventbridge` with `eventbridge = true`
- `aws_dynamodb_table.results`

### Validate

```bash
terraform plan
```

### Observe

Plan should include these **3 adds** (names may differ by prefix):

- S3 bucket
- S3 bucket notification
- DynamoDB table

### Commit checkpoint

```bash
git add doc-processor/main.tf
git commit -m "Add S3 input bucket and DynamoDB results table"
```

### Common failure

- `input_bucket_name` not globally unique -> choose a unique value in `terraform.tfvars`.

---

## Milestone 2: Add Worker Lambdas + Local Packaging

### Build

Create/update:

- `lambdas.tf`
- `lambda/extract/handler.py`
- `lambda/analyze/handler.py`
- `lambda/store/handler.py`

Use `archive_file` data sources to package each handler zip.

### Validate

```bash
terraform plan
python3 -m py_compile lambda/extract/handler.py lambda/analyze/handler.py lambda/store/handler.py
```

### Observe

- Plan includes **3 new Lambda resources**
- Python compile command exits successfully (no syntax errors)

### Commit checkpoint

```bash
git add doc-processor/lambdas.tf doc-processor/lambda
git commit -m "Add extract analyze store lambda workers"
```

### Common failure

- `archive_file` source path typos cause plan errors.

---

## Milestone 3: Add IAM Boundaries

### Build

Create `iam.tf` with:

1. Lambda execution role + policies (`logs`, `s3:GetObject`, `textract:*`, `bedrock:InvokeModel`, `dynamodb:PutItem/UpdateItem`)
2. Step Functions role with `lambda:InvokeFunction` (+ logging permissions)
3. EventBridge role with `states:StartExecution`

### Validate

```bash
terraform validate
terraform plan
```

### Observe

- Validate succeeds
- Plan shows IAM roles, role policies, and policy attachment

### Commit checkpoint

```bash
git add doc-processor/iam.tf
git commit -m "Add IAM roles for lambda stepfunctions and eventbridge"
```

### Common failure

- AccessDenied at runtime almost always traces back to missing action or wrong resource ARN in this file.

---

## Milestone 4: Add Step Functions Orchestration

### Build

Create `stepfunctions.tf` with states:

- `ExtractText`
- `AnalyzeText`
- `StoreResults`
- `RecordFailure`
- `ProcessingFailed`

Include:

- `Retry` on task states
- `Catch` to route to `RecordFailure`
- CloudWatch Logs group and logging config

### Validate

```bash
terraform plan
```

### Observe

- Plan includes state machine and log group
- Definition references the three Lambda ARNs

### Commit checkpoint

```bash
git add doc-processor/stepfunctions.tf
git commit -m "Add state machine with retry catch and failure recording"
```

### Common failure

- Invalid ASL JSON shape (especially JSONPath keys ending in `.$`) causes state machine creation failure.

---

## Milestone 5: Add EventBridge Trigger Wiring

### Build

Create `eventbridge.tf` with:

- Rule filtering:
  - `source = aws.s3`
  - `detail-type = Object Created`
  - matching bucket name
  - key suffix `.pdf`
- Target pointing to the state machine ARN
- EventBridge role ARN attached on target

### Validate

```bash
terraform plan
```

### Observe

- Plan shows EventBridge rule + target
- Target ARN points to the Step Functions state machine

### Commit checkpoint

```bash
git add doc-processor/eventbridge.tf
git commit -m "Wire S3 object events to state machine via EventBridge"
```

### Common failure

- Forgetting `aws_s3_bucket_notification` with `eventbridge = true` means rule never receives S3 events.

---

## Milestone 6: Deploy and Verify Happy Path

### Build

Apply all accumulated changes.

### Validate

```bash
terraform apply
aws s3 cp test.pdf s3://<your-input-bucket-name>/
```

### Observe

1. A new Step Functions execution appears within a few seconds.
2. Execution path reaches `StoreResults`.
3. DynamoDB contains item with at least:
   - `document_id`
   - `status = SUCCEEDED`
   - `analysis`

### Commit checkpoint

No code change required unless you fixed issues discovered during runtime verification. If you changed code, commit with a focused fix message.

---

## Milestone 7: Verify Failure Path (Critical)

### Build

Temporarily force `lambda/analyze/handler.py` to raise an exception.

### Validate

```bash
terraform apply
aws s3 cp test.pdf s3://<your-input-bucket-name>/
```

### Observe

1. `AnalyzeText` retries per policy.
2. Workflow transitions to `RecordFailure`.
3. DynamoDB stores failure row with:
   - `status = FAILED`
   - `error` payload
4. Execution ends in `ProcessingFailed`.

### Commit checkpoint

Revert the forced error and commit restoration:

```bash
git add doc-processor/lambda/analyze/handler.py
git commit -m "Restore analyze lambda after failure-path verification"
```

---

## Verification Matrix (Quick Reference)

| Milestone | Command | Pass signal |
| --- | --- | --- |
| 0 | `terraform validate` | Config valid |
| 1 | `terraform plan` | S3 + notification + DDB |
| 2 | `terraform plan` + `py_compile` | Lambda resources + no syntax errors |
| 3 | `terraform validate` | IAM compiles cleanly |
| 4 | `terraform plan` | SFN + log group planned |
| 5 | `terraform plan` | EventBridge rule + target planned |
| 6 | Upload PDF | SFN success, DDB success row |
| 7 | Inject failure + upload PDF | SFN fail branch, DDB failure row |

## What to Replace the Stubs With

When productionizing:

- **extract**: `boto3.client("textract").detect_document_text(...)`
- **analyze**: `boto3.client("bedrock-runtime").invoke_model(...)`
- **store**: keep handler shape, then evolve DDB item schema to your final analysis model
