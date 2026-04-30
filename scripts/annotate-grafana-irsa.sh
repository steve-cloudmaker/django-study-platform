#!/usr/bin/env bash
# Attach Terraform Grafana IRSA role to the Grafana ServiceAccount (required for CloudWatch panels).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT}/infra/environments/dev"
ARN="$(cd "${TF_DIR}" && terraform output -raw grafana_role_arn)"
kubectl annotate serviceaccount -n monitoring grafana \
  "eks.amazonaws.com/role-arn=${ARN}" \
  --overwrite
kubectl rollout restart deployment/grafana -n monitoring
echo "Annotated monitoring/grafana with ${ARN} and restarted Grafana."
