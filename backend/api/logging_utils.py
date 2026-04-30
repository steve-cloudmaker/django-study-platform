import json
import logging
import uuid
from typing import Any

_logger = logging.getLogger("study_platform")


def log_event(
    message: str,
    *,
    request_id: str | None = None,
    study_id: Any = None,
    submission_id: Any = None,
    extra: dict[str, Any] | None = None,
) -> None:
    payload = {
        "message": message,
        "request_id": request_id,
        "study_id": str(study_id) if study_id is not None else None,
        "submission_id": str(submission_id) if submission_id is not None else None,
    }
    if extra:
        payload.update(extra)
    _logger.info(json.dumps(payload, default=str))


def new_request_id() -> str:
    return str(uuid.uuid4())
