#!/usr/bin/env bash
# Attach ACM certificate ARN to ALB Ingresses (required for HTTPS listeners).
# Prerequisites: terraform apply in infra/environments/dev, kubectl configured for the cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/infra/environments/dev"

ARN="$(terraform output -raw public_acm_certificate_arn 2>/dev/null || true)"
if [[ -z "${ARN}" || "${ARN}" == "null" ]]; then
  echo "public_acm_certificate_arn is empty. Set public_dns_domain and run terraform apply first." >&2
  exit 1
fi

annotate() {
  local ns=$1
  local ing=$2
  kubectl annotate ingress "${ing}" -n "${ns}" \
    "alb.ingress.kubernetes.io/certificate-arn=${ARN}" \
    --overwrite
}

annotate default api
annotate default frontend
annotate monitoring grafana

echo "Annotated ingresses with certificate ARN (HTTPS listeners should reconcile shortly)."
