"""Per-IP rate limit; effective per API replica (see README)."""

from django.conf import settings
from rest_framework.throttling import SimpleRateThrottle


class ClientIPRateThrottle(SimpleRateThrottle):
    """Throttle scope ``api``; rate from settings.API_RATE_LIMIT (e.g. ``60/minute``)."""

    scope = "api"

    def get_rate(self) -> str | None:
        return getattr(settings, "API_RATE_LIMIT", "120/minute")

    def get_cache_key(self, request, view) -> str | None:
        xff = request.META.get("HTTP_X_FORWARDED_FOR")
        if xff:
            ident = xff.split(",")[0].strip()
        else:
            ident = self.get_ident(request)
        return self.cache_format % {"scope": self.scope, "ident": ident}
