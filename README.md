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
Submissions (MVP lab):
1. **Payload text (≤2k)** is stored in **PostgreSQL** with status `pending`.
2. A minimal envelope (`study_id`, `submission_id`, `request_id`) is sent to **SQS**.
3. The **worker** marks the row `processed` (idempotent). **HTTP 202** is returned on enqueue success.

S3 remains in the platform for future raw-object storage; this slice does not write submission bodies to S3.

---

### HTTP API contract (locked for MVP)

| Topic | Behavior |
|--------|-----------|
| **Rate limiting** | `API_RATE_LIMIT` (e.g. `120/minute`, DRF throttle). **Effective per API pod** (in-memory cache); multiple replicas multiply allowance—documented limitation for the lab. Prefer ALB/WAF for hard edges. |
| **Study list `limit`** | Default **10** (`DEFAULT_STUDY_LIST_LIMIT`). Capped at **100** (`MAX_STUDY_LIST_LIMIT`). |
| **Study `name` uniqueness** | **Case-insensitive** unique (`Alpha` conflicts with `alpha`). Names are trimmed on create. |
| **Enqueue failure** | If SQS `SendMessage` fails after the DB insert, the **submission row is deleted** and the API returns **503** with `code: enqueue_failed`. |

**Endpoints** (anonymous, CORS allowed via `DJANGO_CORS_ALLOW_ALL` by default):

- `GET/POST /api/studies/` — list (`?id=<uuid>&name=<str>&limit=<n>`) or create `{"name":"..."}`.
- `GET /api/studies/<study_id>/` — study detail.
- `POST /api/studies/<study_id>/submissions/` — create `{"content":"..."}` → **202** + `Location` (worker processes asynchronously).
- `GET /api/studies/<study_id>/submissions/<submission_id>/` — submission detail.

**Caps:** `MAX_STUDY_COUNT` rejects new studies with **409** (`code: max_studies`).

---

### Observability-First Design
System health is exposed via:
- Prometheus metrics (`GET /metrics` on the Django API — see `django-prometheus` in `backend/config/settings.py`)
- Grafana dashboards (embedded in UI)

---

### Frontend Deployment
- Minimal deployment (no CDN for MVP)
- Public endpoint served over HTTPS via ALB Ingress (`app.charliesystems.ai`)
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

### API load test (optional)

See [loadtest/README.md](loadtest/README.md): Textual TUI, read/write QPS, **duration** and **ramp-up**, 100 cached smartphone-usage surveys as submission payloads.

---

## Deployment (High-Level)

1. Provision infrastructure with Terraform (`infra/environments/dev`): `terraform init` then `terraform apply`. See the header comment in [infra/environments/dev/main.tf](infra/environments/dev/main.tf) for installing the **AWS Load Balancer Controller** (IRSA role ARN is a Terraform output) and using **IngressClass `alb`**.
2. Build Docker images
3. Push to ECR
4. Deploy to EKS (`kubectl apply -k k8s/base` after editing placeholders in `k8s/base/`)

### After API or model changes (runtime refresh)

The cluster runs whatever digest/tag ECR resolves for `study-platform-api:latest`. **Rebuild and push** whenever `backend/` changes, then:

```bash
kubectl apply -k k8s/base
kubectl rollout restart deployment/api deployment/worker -n default
kubectl rollout status deployment/api deployment/worker -n default --timeout=300s
kubectl exec -n default deploy/api -- python manage.py migrate --noinput
```

Smoke test against the public ingress (override host if needed):

```bash
BASE_URL=https://api.charliesystems.ai bash scripts/smoke-test-api.sh
```

Until a new API image is deployed, `run_submission_worker` is missing from the image and worker pods may **CrashLoop** if the manifest points at an old `:latest` digest—fix by pushing a fresh image or temporarily using the previous worker stub command.

---

## Observability

After the API is running, install Prometheus, kube-state-metrics, and Grafana (dashboard JSON + scrape config):

```bash
kubectl apply -k k8s/observability
kubectl -n monitoring port-forward svc/grafana 3000:3000
```

After `terraform apply`, attach the Grafana CloudWatch IAM role to the Grafana ServiceAccount (one-time per cluster):

```bash
bash scripts/annotate-grafana-irsa.sh
```

Dashboard source: [k8s/observability/dashboards/study-platform-api.json](k8s/observability/dashboards/study-platform-api.json) (provisioned automatically). Default Grafana login uses Secret `grafana-admin` in namespace `monitoring` — change the password before production.

Grafana dashboards include:
- Django API: request rate, status mix, latency, 5xx ratio (Prometheus `job=django-api`)
- Worker: Deployment desired/available/updated replicas and HPA min/current/max (Prometheus via **kube-state-metrics**, `job=kube-state-metrics`)
- SQS: main queue visible and in-flight counts, DLQ visible messages (CloudWatch; queue names are dashboard variables — align with `terraform output submissions_queue_name` / `submissions_dlq_name`)

Grafana is exposed at `https://grafana.charliesystems.ai` and can be embedded in the frontend (anonymous Viewer mode + embedding enabled in `k8s/observability/grafana.yaml`).

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

### 5) Public HTTPS (`charliesystems.ai`)

Terraform provisions an **AWS-managed ACM certificate** (wildcard `*.charliesystems.ai` plus apex) and **Route53 alias** records:

- `api.charliesystems.ai` → API ALB
- `app.charliesystems.ai` → frontend ALB
- `grafana.charliesystems.ai` → Grafana ALB

Defaults live in `infra/environments/dev/variables.tf` (`public_dns_domain`, ALB names). If ALBs do not exist yet, set `create_route53_alb_aliases = false` for the first `terraform apply`, then set it back to `true` after ingresses exist.

```bash
export AWS_PROFILE=dev-lab
export AWS_DEFAULT_REGION=us-west-1
cd infra/environments/dev
terraform apply
```

After ingress manifests are applied, attach the certificate ARN to the three ingresses:

```bash
./scripts/apply-acm-certificate-to-ingress.sh
```

Then re-apply Kubernetes so the frontend and Grafana use HTTPS URLs:

```bash
kubectl apply -k k8s/base
kubectl apply -k k8s/observability
```

Verify secure endpoints:

```bash
curl -I https://api.charliesystems.ai/healthz/
curl -I https://app.charliesystems.ai/
curl -I https://grafana.charliesystems.ai/
```

Expected:
- `https://api.charliesystems.ai/healthz/` returns `200`
- `https://app.charliesystems.ai/` returns `200`
- `https://grafana.charliesystems.ai/` returns `200`
- HTTP variants redirect to HTTPS (`301`)

---

## Future Enhancements

- CDN via CloudFront
- Autoscaling via KEDA
- Advanced analytics
- Multi-region deployment

---