import json


def lambda_handler(event, context):
    # TODO: call Bedrock with event["extracted_text"]
    print("Analyze called with:", json.dumps(event))

    return {
        **event,
        "analysis": "stub analysis result",
    }
