from django.urls import path

from . import views

urlpatterns = [
    path("studies/", views.StudyListCreateView.as_view(), name="study-list"),
    path(
        "studies/<uuid:study_id>/",
        views.StudyDetailView.as_view(),
        name="study-detail",
    ),
    path(
        "studies/<uuid:study_id>/submissions/",
        views.SubmissionCreateView.as_view(),
        name="submission-list",
    ),
    path(
        "studies/<uuid:study_id>/submissions/<uuid:submission_id>/",
        views.SubmissionDetailView.as_view(),
        name="submission-detail",
    ),
]
