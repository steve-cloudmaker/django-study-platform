import json
import logging
import time
import uuid

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import transaction

from api.logging_utils import log_event
from api.models import Submission

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Long-poll SQS and mark submissions processed (idempotent lab worker)."

    def handle(self, *args, **options):
        url = getattr(settings, "SQS_SUBMISSIONS_QUEUE_URL", "") or ""
        if not url:
            raise SystemExit("SQS_SUBMISSIONS_QUEUE_URL is not set")

        region = getattr(settings, "AWS_REGION", None) or "us-west-1"
        client = boto3.client("sqs", region_name=region)
        self.stdout.write(self.style.NOTICE(f"Polling {url} in {region}"))

        while True:
            try:
                resp = client.receive_message(
                    QueueUrl=url,
                    MaxNumberOfMessages=5,
                    WaitTimeSeconds=20,
                    VisibilityTimeout=60,
                )
            except (ClientError, BotoCoreError) as exc:
                logger.exception("receive_message failed: %s", exc)
                time.sleep(5)
                continue

            for msg in resp.get("Messages", []):
                self._process_one(client, url, msg)

    def _process_one(self, client, queue_url: str, msg: dict) -> None:
        receipt = msg["ReceiptHandle"]
        try:
            body = json.loads(msg["Body"])
            study_id = uuid.UUID(body["study_id"])
            submission_id = uuid.UUID(body["submission_id"])
            request_id = body.get("request_id", "")
        except (KeyError, ValueError, json.JSONDecodeError) as exc:
            logger.warning("Malformed message, deleting: %s %s", msg.get("MessageId"), exc)
            client.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt)
            return

        try:
            with transaction.atomic():
                sub = Submission.objects.select_for_update().get(
                    study_id=study_id,
                    submission_id=submission_id,
                )
                if sub.status == Submission.Status.PROCESSED:
                    log_event(
                        "worker_skip_processed",
                        request_id=request_id,
                        study_id=study_id,
                        submission_id=submission_id,
                    )
                else:
                    sub.status = Submission.Status.PROCESSED
                    sub.save(update_fields=["status"])
                    log_event(
                        "worker_marked_processed",
                        request_id=request_id,
                        study_id=study_id,
                        submission_id=submission_id,
                    )
        except Submission.DoesNotExist:
            logger.warning("Submission not found for message; deleting: %s", submission_id)
        except Exception:
            logger.exception("Processing failed for %s/%s", study_id, submission_id)
            return

        try:
            client.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt)
        except (ClientError, BotoCoreError):
            logger.exception("delete_message failed")
