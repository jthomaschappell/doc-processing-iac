# HUMAN_MANUAL_TESTS_document-processing

Run these manual tests after deploying the Terraform in `doc-processor/`.

## Test 1: Happy path PDF processing

1. Upload a PDF file:

   ```bash
   aws s3 cp test.pdf s3://<input-bucket-name>/
   ```

2. Open Step Functions and verify a new execution starts.
3. Confirm states run in order: `ExtractText` -> `AnalyzeText` -> `StoreResults`.
4. Confirm execution status is **Succeeded**.

Expected result:

- DynamoDB table has an item with `document_id`, `status = SUCCEEDED`, and `analysis`.

## Test 2: Event filter enforcement

1. Upload a non-PDF file:

   ```bash
   aws s3 cp notes.txt s3://<input-bucket-name>/
   ```

2. Watch Step Functions executions for 30 seconds.

Expected result:

- No new execution starts (rule filters to `.pdf` suffix).

## Test 3: Failure capture path

1. Temporarily modify `lambda/analyze/handler.py` to raise an exception.
2. Redeploy Lambda (`terraform apply`).
3. Upload a PDF.
4. Inspect execution graph.

Expected result:

- `AnalyzeText` retries according to policy.
- Workflow transitions to `RecordFailure` then `ProcessingFailed`.
- DynamoDB row exists with `status = FAILED` and `error` payload.

## Test 4: Idempotent re-runs sanity check

1. Upload the same PDF twice.
2. Observe two Step Functions executions.

Expected result:

- Both executions complete.
- DynamoDB behavior follows your chosen `document_id` strategy (overwrite or distinct IDs).
