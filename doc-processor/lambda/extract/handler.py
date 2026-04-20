import json


def lambda_handler(event, context):
    # TODO: use boto3 Textract to extract text from bucket/key.
    # Accept either normalized state input or raw EventBridge S3 event.
    print("Extract called with:", json.dumps(event))

    detail = event.get("detail", {})
    detail_bucket = detail.get("bucket", {})
    detail_object = detail.get("object", {})

    bucket = event.get("bucket") or detail_bucket.get("name")
    key = event.get("key") or detail_object.get("key")
    document_id = (
        event.get("document_id")
        or detail_object.get("etag")
        or key
        or "unknown-document"
    )

    return {
        "document_id": document_id,
        "bucket": bucket,
        "key": key,
        "extracted_text": "stub text from PDF",
    }
