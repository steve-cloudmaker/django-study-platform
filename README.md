# README.md

## Resilient Study Platform

A reliability-focused study collection system designed to demonstrate **SRE best practices** including:
- Asynchronous processing
- Backpressure handling
- Observability (metrics + dashboards)
- Scalable infrastructure on AWS

---

Step-by-step AWS bootstrap (profile **`dev-lab`**, **`us-west-1`**, locked-down EKS API): [QUICKSTART.md](QUICKSTART.md).

---

## Architecture Overview

- Next.js frontend (SPA)
- Django REST API (EKS)
- Worker service (EKS)
- Amazon SQS (queue)
- Amazon RDS (PostgreSQL)
- Amazon S3 (raw data storage)
- Grafana (observability dashboards)

---

## Key Design Decisions

### Async Submission Pipeline
Submissions are:
1. Stored in S3
2. Sent to SQS
3. Processed asynchronously by workers

This ensures:
- Fast API response times
- Resilience under load

---

### Observability-First Design
System health is exposed via:
- Prometheus metrics (`GET /metrics` on the Django API — see `django-prometheus` in `backend/config/settings.py`)
- Grafana dashboards (embedded in UI)

---

### Frontend Deployment
- Minimal deployment (no CDN for MVP)
- Future: CloudFront for edge caching

---

## Running Locally

### Requirements
- Docker
- Python 3.11+
- Node.js 18+

### Steps

```bash
# backend
cd backend
docker-compose up

# frontend
cd frontend
npm install
npm run dev
```

---

## Deployment (High-Level)

1. Provision infrastructure with Terraform (`infra/environments/dev`): `terraform init` then `terraform apply`. See the header comment in [infra/environments/dev/main.tf](infra/environments/dev/main.tf) for installing the **AWS Load Balancer Controller** (IRSA role ARN is a Terraform output) and using **IngressClass `alb`**.
2. Build Docker images
3. Push to ECR
4. Deploy to EKS (`kubectl apply -k k8s/base` after editing placeholders in `k8s/base/`)

---

## Observability

After the API is running, install Prometheus and Grafana (dashboard JSON + scrape config):

```bash
kubectl apply -k k8s/observability
kubectl -n monitoring port-forward svc/grafana 3000:3000
```

Dashboard source: [k8s/observability/dashboards/study-platform-api.json](k8s/observability/dashboards/study-platform-api.json) (provisioned automatically). Default Grafana login uses Secret `grafana-admin` in namespace `monitoring` — change the password before production.

Grafana dashboards include:
- API latency (p95)
- Request rate
- Error rate
- Queue depth
- Worker throughput

---

## Post-Install Full Verification

Use this checklist after `terraform apply` and `kubectl apply` to confirm the stack is healthy.

### 1) Verify AWS resources

```bash
export AWS_PROFILE=dev-lab
export AWS_DEFAULT_REGION=us-west-1

cd infra/environments/dev
terraform output
```

Confirm these outputs exist and look correct:
- `cluster_name`
- `rds_endpoint`
- `submissions_queue_url`
- `submissions_bucket`
- `api_role_arn` and `worker_role_arn`

Then verify core resources are live:

```bash
aws eks describe-cluster --name "$(terraform output -raw cluster_name)" \
  --query 'cluster.{name:name,status:status,version:version}' --output table

aws rds describe-db-instances --db-instance-identifier study-platform-dev-postgres \
  --query 'DBInstances[0].{id:DBInstanceIdentifier,status:DBInstanceStatus,endpoint:Endpoint.Address}' --output table

aws sqs get-queue-attributes --queue-url "$(terraform output -raw submissions_queue_url)" \
  --attribute-names QueueArn ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --output table

aws s3api head-bucket --bucket "$(terraform output -raw submissions_bucket)"
```

### 2) Verify Kubernetes workloads

```bash
aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name "$(terraform output -raw cluster_name)"
kubectl get nodes -o wide
kubectl get pods -A
kubectl get deploy -A
kubectl get hpa -A
```

Expect `api`, `worker`, `prometheus`, and `grafana` Deployments to be `READY`.

### 3) Verify API and Grafana health endpoints

```bash
# Terminal 1
kubectl port-forward -n default svc/api 18080:80

# Terminal 2
kubectl port-forward -n monitoring svc/grafana 13000:3000
```

From a third terminal:

```bash
curl -i http://127.0.0.1:18080/healthz/
curl -i http://127.0.0.1:13000/api/health
```

Expected:
- API healthcheck returns `HTTP 200` with body `ok`
- Grafana health returns `HTTP 200` and includes `"database":"ok"`

### 4) Verify external reachability (ALB / Ingress)

External reachability requires an Ingress plus AWS Load Balancer Controller.

```bash
kubectl get ingress -A -o wide
```

If an Ingress hostname is present, test publicly:

```bash
ALB_DNS="<ingress-hostname>"
curl -i "http://${ALB_DNS}/healthz/"
```

If `kubectl get ingress` shows no resources, external reachability is not configured yet. In that case, complete AWS Load Balancer Controller + Ingress setup first (see deployment notes in `infra/environments/dev/main.tf`).

---

## Future Enhancements

- CDN via CloudFront
- Autoscaling via KEDA
- Advanced analytics
- Multi-region deployment

---