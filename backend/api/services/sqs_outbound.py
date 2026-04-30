import json
import logging

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from django.conf import settings

logger = logging.getLogger(__name__)


def enqueue_submission_job(
    *,
    study_id,
    submission_id,
    request_id: str,
) -> None:
    """Publish a minimal envelope to SQS. Raises on client errors."""
    url = getattr(settings, "SQS_SUBMISSIONS_QUEUE_URL", "") or ""
    if not url:
        raise RuntimeError("SQS_SUBMISSIONS_QUEUE_URL is not configured")

    region = getattr(settings, "AWS_REGION", None) or "us-west-1"
    client = boto3.client("sqs", region_name=region)
    body = json.dumps(
        {
            "study_id": str(study_id),
            "submission_id": str(submission_id),
            "request_id": request_id,
        }
    )
    try:
        client.send_message(QueueUrl=url, MessageBody=body)
    except (ClientError, BotoCoreError) as exc:
        logger.exception("SQS send_message failed: %s", exc)
        raise
