from django.contrib import admin
from django.urls import include, path

from api.views import healthz

urlpatterns = [
    path("admin/", admin.site.urls),
    path("healthz/", healthz, name="healthz"),
    path("healthz", healthz, name="healthz-no-slash"),
    path("", include("django_prometheus.urls")),
    path("api/", include("api.urls")),
]
