from __future__ import annotations

import uuid
from typing import TYPE_CHECKING

from django.conf import settings
from django.db.models import QuerySet

from ..models import Study

if TYPE_CHECKING:
    pass


def parse_list_limit(raw: str | None) -> int:
    default = getattr(settings, "DEFAULT_STUDY_LIST_LIMIT", 10)
    cap = getattr(settings, "MAX_STUDY_LIST_LIMIT", 100)
    if raw is None or raw == "":
        return default
    try:
        n = int(raw)
    except ValueError:
        return default
    if n < 1:
        return 1
    return min(n, cap)


def filter_studies(
    *,
    study_id: str | None,
    name: str | None,
) -> QuerySet[Study]:
    qs: QuerySet[Study] = Study.objects.all().order_by("-created_at")
    if study_id:
        try:
            uid = uuid.UUID(study_id)
        except ValueError:
            return Study.objects.none()
        qs = qs.filter(id=uid)
    if name is not None and name.strip() != "":
        qs = qs.filter(name__iexact=name.strip())
    return qs
