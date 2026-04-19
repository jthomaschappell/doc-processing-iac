import json
import os

import boto3


def lambda_handler(event, context):
    table = boto3.resource("dynamodb").Table(os.environ["RESULTS_TABLE"])
    detail = event.get("detail", {})
    object_detail = detail.get("object", {})

    document_id = (
        event.get("document_id")
        or object_detail.get("etag")
        or context.aws_request_id
    )
    bucket = event.get("bucket") or detail.get("bucket", {}).get("name")
    key = event.get("key") or object_detail.get("key")

    item = {
        "document_id": document_id,
        "status": event.get("status", "SUCCEEDED"),
    }

    # Write optional metadata fields when present.
    if "analysis" in event:
        item["analysis"] = event["analysis"]
    if bucket:
        item["bucket"] = bucket
    if key:
        item["object_key"] = key
    if "error" in event:
        item["error"] = json.dumps(event["error"])

    table.put_item(Item=item)
    print("Stored result for:", document_id)
    return {"status": "stored", "document_id": document_id}
