# Quick start (AWS profile `dev-lab`, region `us-west-1`)

This guide provisions the Terraform stack, builds container images, and applies Kubernetes manifests. Defaults match [infra/environments/dev/variables.tf](infra/environments/dev/variables.tf): **`us-west-1`** and **EKS public API access allowed only from `98.51.205.17/32`**. Nodes still reach the control plane over the **private** endpoint inside the VPC.

**Important:** Update `eks_public_access_cidrs` if your home IP changes or CI/CD needs API access. Internet-facing **Application Load Balancers** created later by the AWS Load Balancer Controller are **not** restricted by this setting (they remain publicly reachable unless you add SG/Ingress rules).

---

## Prerequisites

- Terraform `>= 1.5`, AWS CLI v2, `kubectl`, Docker (for images), optional Helm (for AWS LB Controller)
- AWS account access via profile **`dev-lab`** (organizational account / role however you map it in `~/.aws/config`)

---

## 1. Configure shell

```bash
cd /path/to/django-study-platform

export AWS_PROFILE=dev-lab
export AWS_DEFAULT_REGION=us-west-1

aws sts get-caller-identity
```

You should see the expected account and ARN for `dev-lab`.

---

## 2. Provision infrastructure

```bash
cd infra/environments/dev
terraform init -upgrade
terraform apply
```

On success, note outputs: cluster name, bucket, queue URL, IAM role ARNs, RDS secret ARN.

```bash
terraform output
```

Refresh kubeconfig:

```bash
aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name "$(terraform output -raw cluster_name)"
kubectl get nodes
```

---

## 3. Build and push images (ECR)

Repository names below are examples; adjust if your org standardizes names.

```bash
cd ../..   # repo root
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="${AWS_DEFAULT_REGION:-us-west-1}"

for repo in study-platform-api study-platform-worker; do
  aws ecr describe-repositories --repository-names "$repo" --region "$REGION" 2>/dev/null \
    || aws ecr create-repository --repository-name "$repo" --region "$REGION"
done

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker build -t study-platform-api:latest -f backend/Dockerfile backend/
docker tag study-platform-api:latest "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/study-platform-api:latest"
docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/study-platform-api:latest"

# Worker image: same app image with a different command is fine for MVP, or build a worker target later.
docker tag study-platform-api:latest "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/study-platform-worker:latest"
docker push "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/study-platform-worker:latest"
```

---

## 4. Patch Kubernetes manifests from Terraform

From repo root, with shell still using `AWS_PROFILE` and after `cd infra/environments/dev && terraform apply`:

```bash
cd infra/environments/dev
API_ROLE=$(terraform output -raw api_role_arn)
WORKER_ROLE=$(terraform output -raw worker_role_arn)
BUCKET=$(terraform output -raw submissions_bucket)
QUEUE=$(terraform output -raw submissions_queue_url)
REGION=$(terraform output -raw aws_region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_API="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/study-platform-api:latest"
cd ../..

sed -i.bak \
  -e "s|arn:aws:iam::000000000000:role/REPLACE_WITH_api_role_arn|${API_ROLE}|g" \
  -e "s|arn:aws:iam::000000000000:role/REPLACE_WITH_worker_role_arn|${WORKER_ROLE}|g" \
  k8s/base/serviceaccount-api.yaml k8s/base/serviceaccount-worker.yaml

sed -i.bak \
  -e "s|REPLACE_ME_BUCKET|${BUCKET}|g" \
  -e "s|REPLACE_ME_QUEUE_URL|${QUEUE}|g" \
  -e "s|us-east-1|${REGION}|g" \
  k8s/base/configmap-app.yaml

sed -i.bak \
  -e "s|REPLACE_ME_API_IMAGE:latest|${IMAGE_API}|g" \
  k8s/base/deployment-api.yaml
```

The worker Deployment uses the **same API image** and `python manage.py run_submission_worker`; ensure `k8s/base/deployment-worker.yaml` points at your `study-platform-api` ECR URL after you build and push.

On macOS, `sed -i ''` works instead of `sed -i.bak`; adjust if needed.

Create the DB secret when RDS is ready (Terraform-managed master password in Secrets Manager). The JSON from AWS **may omit `host`**, so merge `rds_endpoint` from Terraform:

```bash
cd infra/environments/dev
SECRET_ARN=$(terraform output -raw rds_master_user_secret_arn)
RDS_HOST=$(terraform output -raw rds_endpoint)
RDS_DB=$(terraform output -raw rds_db_name)
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)

DATABASE_URL=$(SECRET_JSON="$SECRET_JSON" RDS_HOST="$RDS_HOST" RDS_DB="$RDS_DB" python3 << 'PY'
import json, os, urllib.parse
j = json.loads(os.environ["SECRET_JSON"])
user = urllib.parse.quote(str(j["username"]), safe="")
pw = urllib.parse.quote(str(j["password"]), safe="")
host = (j.get("host") or "").strip() or os.environ["RDS_HOST"]
port = int(j.get("port") or 5432)
db = j.get("dbname") or j.get("database") or os.environ["RDS_DB"]
print(f"postgresql://{user}:{pw}@{host}:{port}/{db}")
PY
)

kubectl delete secret api-secrets --ignore-not-found
kubectl create secret generic api-secrets --from-literal=database-url="$DATABASE_URL"
```

---

## 5. Apply workloads and observability

```bash
kubectl apply -k k8s/base
```

Run migrations once (same image and env as the API Deployment):

```bash
IMAGE=$(grep -E '^\s+image:' k8s/base/deployment-api.yaml | head -1 | awk '{print $2}')
kubectl delete job django-migrate-once --ignore-not-found
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: django-migrate-once
  namespace: default
spec:
  ttlSecondsAfterFinished: 86400
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: api
      containers:
        - name: migrate
          image: ${IMAGE}
          command: ["python", "manage.py", "migrate", "--noinput"]
          envFrom:
            - configMapRef:
                name: app-config
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: api-secrets
                  key: database-url
EOF
kubectl wait --for=condition=complete job/django-migrate-once --timeout=300s
```

HPAs need **metrics-server** (not installed by default on all clusters):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

Observability stack:

```bash
kubectl apply -k k8s/observability
```

Install the AWS Load Balancer Controller when you need an ALB (see comment block in [infra/environments/dev/main.tf](infra/environments/dev/main.tf)).

---

## 6. Run API locally (no AWS)

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Metrics: `curl -s localhost:8000/metrics | head`

---

## Troubleshooting

- **`The config profile (dev-lab) could not be found`:** Define profile `dev-lab` in `~/.aws/config` (SSO or role), then re-run `export AWS_PROFILE=dev-lab`.
- **`kubectl` timeouts / TLS errors:** Your current public IP must be in `eks_public_access_cidrs`. Edit [infra/environments/dev/variables.tf](infra/environments/dev/variables.tf) or pass `-var='eks_public_access_cidrs=["YOUR.IP.HERE/32"]'` and `terraform apply`.
- **EKS version unavailable in `us-west-1`:** Set `kubernetes_version` to a version supported in that region.
- **Docker build fails:** Start Docker Desktop (or your daemon), then re-run the `docker build` / `docker push` steps.
