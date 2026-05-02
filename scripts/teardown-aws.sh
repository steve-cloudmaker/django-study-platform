#!/usr/bin/env bash
# Full teardown: Kubernetes cleanup then terraform destroy for infra/environments/dev.
# Requires: AWS CLI v2, kubectl, terraform. Set AWS_PROFILE (and AWS_DEFAULT_REGION) as needed.
# See docs/TEARDOWN.md for manual steps and safety checks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT}/infra/environments/dev"
export AWS_PROFILE="${AWS_PROFILE:-dev-lab}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-west-1}"

echo "== AWS identity =="
aws sts get-caller-identity

echo "== Terraform init (${TF_DIR}) =="
cd "$TF_DIR"
terraform init -input=false

cluster_name=""
if terraform output -raw cluster_name &>/dev/null; then
  cluster_name="$(terraform output -raw cluster_name)"
fi

if [[ -n "${cluster_name}" ]]; then
  echo "== EKS kubeconfig (${cluster_name}) =="
  aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name "$cluster_name" || true

  echo "== Delete Ingress (ALB) =="
  kubectl delete ingress --all -n default --ignore-not-found --wait=true || true
  kubectl delete ingress --all -n monitoring --ignore-not-found --wait=true || true

  echo "== Scale deployments to zero =="
  for dep in api worker frontend; do
    kubectl scale "deployment/${dep}" --replicas=0 -n default 2>/dev/null || true
  done

  echo "== Delete kustomize stacks =="
  cd "$ROOT"
  kubectl delete -k k8s/observability --ignore-not-found --wait=true || true
  kubectl delete -k k8s/base --ignore-not-found --wait=true || true
  cd "$TF_DIR"
else
  echo "== No cluster_name in Terraform state; skipping kubectl =="
fi

echo "== terraform destroy =="
cd "$TF_DIR"
# After Ingress deletion, ALBs may be gone while state still references them (e.g. public_https data.aws_lb).
# -refresh=false uses last-known state so destroy can proceed.
terraform destroy -refresh=false -auto-approve

echo "== Teardown finished =="
