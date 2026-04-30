from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient

from .models import Study, Submission


class StudyApiTests(TestCase):
    def setUp(self) -> None:
        self.client = APIClient()

    def test_create_and_list_by_name(self) -> None:
        r = self.client.post("/api/studies/", {"name": " Alpha "}, format="json")
        self.assertEqual(r.status_code, status.HTTP_201_CREATED)
        self.assertIn("id", r.data)
        r2 = self.client.get("/api/studies/", {"name": "alpha"})
        self.assertEqual(r2.status_code, status.HTTP_200_OK)
        self.assertEqual(len(r2.data), 1)
        self.assertEqual(r2.data[0]["name"], "Alpha")

    def test_duplicate_name(self) -> None:
        Study.objects.create(name="Dup")
        r = self.client.post("/api/studies/", {"name": "dup"}, format="json")
        self.assertEqual(r.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(r.data.get("code"), "duplicate_name")

    @patch("api.views.enqueue_submission_job")
    def test_submission_202(self, mock_enqueue) -> None:
        mock_enqueue.return_value = None
        st = Study.objects.create(name="S")
        r = self.client.post(
            f"/api/studies/{st.id}/submissions/",
            {"content": "hello"},
            format="json",
        )
        self.assertEqual(r.status_code, status.HTTP_202_ACCEPTED)
        self.assertEqual(r.data["status"], "pending")
        self.assertIn("submission_id", r.data)
        mock_enqueue.assert_called_once()
        sub = Submission.objects.get(study=st)
        self.assertEqual(sub.content, "hello")
