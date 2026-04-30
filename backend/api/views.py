from __future__ import annotations

import uuid

from django.conf import settings
from django.db import IntegrityError, transaction
from django.http import HttpRequest
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .logging_utils import log_event, new_request_id
from .models import Study, Submission
from .serializers import (
    StudyCreateSerializer,
    StudySerializer,
    SubmissionCreateSerializer,
    SubmissionDetailSerializer,
)
from .services.sqs_outbound import enqueue_submission_job
from .services.study_query import filter_studies, parse_list_limit
from .throttling import ClientIPRateThrottle


def _request_id(request: HttpRequest) -> str:
    rid = request.headers.get("X-Request-Id") or getattr(request, "_study_request_id", None)
    if not rid:
        rid = new_request_id()
    request._study_request_id = rid  # type: ignore[attr-defined]
    return rid


class StudyListCreateView(APIView):
    """GET: filter by ``id`` and/or ``name``; ``limit`` capped. POST: create study."""

    throttle_classes = [ClientIPRateThrottle]

    def get(self, request: HttpRequest) -> Response:
        rid = _request_id(request)
        limit = parse_list_limit(request.query_params.get("limit"))
        qs = filter_studies(
            study_id=request.query_params.get("id"),
            name=request.query_params.get("name"),
        )[:limit]
        data = StudySerializer(qs, many=True).data
        log_event("studies_list", request_id=rid, extra={"count": len(data)})
        return Response(data)

    def post(self, request: HttpRequest) -> Response:
        rid = _request_id(request)
        if Study.objects.count() >= getattr(settings, "MAX_STUDY_COUNT", 10_000):
            log_event("study_create_rejected_max", request_id=rid)
            return Response(
                {"detail": "Study limit reached.", "code": "max_studies"},
                status=status.HTTP_409_CONFLICT,
            )
        ser = StudyCreateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        try:
            study = Study.objects.create(name=ser.validated_data["name"])
        except IntegrityError:
            log_event("study_create_duplicate_name", request_id=rid)
            return Response(
                {"detail": "A study with this name already exists.", "code": "duplicate_name"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        log_event("study_created", request_id=rid, study_id=study.id)
        return Response(StudySerializer(study).data, status=status.HTTP_201_CREATED)


class StudyDetailView(APIView):
    throttle_classes = [ClientIPRateThrottle]

    def get(self, request: HttpRequest, study_id: uuid.UUID) -> Response:
        rid = _request_id(request)
        study = get_object_or_404(Study, pk=study_id)
        log_event("study_retrieve", request_id=rid, study_id=study.id)
        return Response(StudySerializer(study).data)


class SubmissionCreateView(APIView):
    """Create submission, persist 2k text in Postgres, enqueue SQS, return 202."""

    throttle_classes = [ClientIPRateThrottle]

    def post(self, request: HttpRequest, study_id: uuid.UUID) -> Response:
        rid = _request_id(request)
        study = get_object_or_404(Study, pk=study_id)
        ser = SubmissionCreateSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        submission_id = uuid.uuid4()
        with transaction.atomic():
            sub = Submission(
                study=study,
                submission_id=submission_id,
                content=ser.validated_data["content"],
                status=Submission.Status.PENDING,
            )
            sub.save()

        try:
            enqueue_submission_job(
                study_id=study.id,
                submission_id=sub.submission_id,
                request_id=rid,
            )
        except Exception:
            Submission.objects.filter(
                study_id=study.id,
                submission_id=sub.submission_id,
            ).delete()
            log_event(
                "submission_enqueue_failed",
                request_id=rid,
                study_id=study.id,
                submission_id=sub.submission_id,
            )
            return Response(
                {"detail": "Failed to enqueue submission.", "code": "enqueue_failed"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        log_event(
            "submission_enqueued",
            request_id=rid,
            study_id=study.id,
            submission_id=sub.submission_id,
        )
        loc = request.build_absolute_uri(
            f"/api/studies/{study.id}/submissions/{sub.submission_id}/"
        )
        return Response(
            {
                "study_id": str(study.id),
                "submission_id": str(sub.submission_id),
                "status": sub.status,
            },
            status=status.HTTP_202_ACCEPTED,
            headers={"Location": loc},
        )


class SubmissionDetailView(APIView):
    throttle_classes = [ClientIPRateThrottle]

    def get(self, request: HttpRequest, study_id: uuid.UUID, submission_id: uuid.UUID) -> Response:
        rid = _request_id(request)
        sub = get_object_or_404(
            Submission,
            study_id=study_id,
            submission_id=submission_id,
        )
        log_event(
            "submission_retrieve",
            request_id=rid,
            study_id=sub.study_id,
            submission_id=sub.submission_id,
        )
        return Response(SubmissionDetailSerializer(sub).data)


def healthz(request: HttpRequest):
    from django.http import HttpResponse

    return HttpResponse("ok", content_type="text/plain")
