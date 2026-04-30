import uuid

from django.db import models
from django.db.models.functions import Lower


class Study(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                Lower("name"),
                name="uq_study_name_ci",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.id})"


class Submission(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        PROCESSED = "processed", "Processed"

    study = models.ForeignKey(Study, on_delete=models.CASCADE, db_column="study_id")
    submission_id = models.UUIDField(default=uuid.uuid4, editable=False)
    pk = models.CompositePrimaryKey("study_id", "submission_id")
    content = models.TextField(max_length=2000)
    status = models.CharField(
        max_length=32,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"{self.study_id}/{self.submission_id}"
