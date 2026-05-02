# Ops runbook: full AWS teardown

This runbook shuts down the Resilient Study Platform **application stack** and removes **all Terraform-managed infrastructure** in `infra/environments/dev` (VPC, EKS, RDS, S3, SQS+DLQ, IAM/IRSA, optional public HTTPS module).

**Outcome:** Irreversible data loss unless you take optional backups first (RDS snapshot, S3 sync). RDS in this repo uses `skip_final_snapshot = true`; the S3 submissions bucket uses `force_destroy = true`.

**Automated run (repo root):** With valid AWS credentials (`aws sts get-caller-identity` succeeds), run `bash scripts/teardown-aws.sh`. The script defaults `AWS_PROFILE` to `dev-lab` and `AWS_DEFAULT_REGION` to `us-west-1` (override if needed). CI sandboxes and some agent environments do not mount your `~/.aws` profile; in that case run the same script on your workstation after `aws sso login` or `aws configure`.

---

## Phase 0 — Preconditions

1. Use the same **AWS profile** and **region** you used for `terraform apply` (see [QUICKSTART.md](../QUICKSTART.md)).

   ```bash
   export AWS_PROFILE=dev-lab          # adjust
   export AWS_DEFAULT_REGION=us-west-1
   aws sts get-caller-identity
   ```

2. Optional: RDS final snapshot, S3 `aws s3 sync`, export Grafana dashboards.

3. From the repo root, capture outputs for the audit trail:

   ```bash
   cd infra/environments/dev
   terraform output
   ```

---

## Phase 1 — Graceful Kubernetes shutdown

**Run from repo root** after kubeconfig points at the target cluster.

1. **Cluster API access**

   ```bash
   cd infra/environments/dev
   aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name "$(terraform output -raw cluster_name)"
   cd ../..
   ```

2. **Stop ingress traffic (ALB)** — delete Ingress objects first so the AWS Load Balancer Controller can remove ELBv2 load balancers before subnets/VPC teardown.

   ```bash
   kubectl delete ingress --all -n default --ignore-not-found
   kubectl delete ingress --all -n monitoring --ignore-not-found
   ```

   Wait until ALBs disappear in the EC2 → Load balancers console, or re-run `kubectl get ingress -A` until none remain.

3. **Scale workloads to zero** (optional if you will delete manifests immediately after; keeps a short window with no new API traffic).

   ```bash
   kubectl scale deployment/api deployment/worker deployment/frontend --replicas=0 -n default --ignore-not-found
   ```

4. **Queues** — drain the main submissions queue (and DLQ if required by policy), or purge after sign-off:

   ```bash
   # Example: purge (destructive)
   # aws sqs purge-queue --queue-url "$(terraform output -raw submissions_queue_url)"
   ```

5. **Helm** — if the AWS Load Balancer Controller (or other charts) are installed:

   ```bash
   helm list -A
   # helm uninstall aws-load-balancer-controller -n kube-system   # if present
   ```

6. **Delete applied manifests** (order: observability namespace often has its own ingress already removed in step 2).

   ```bash
   kubectl delete -k k8s/observability --ignore-not-found
   kubectl delete -k k8s/base --ignore-not-found
   ```

7. **Metrics Server** (if applied from upstream YAML per QUICKSTART) — optional cleanup:

   ```bash
   kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml --ignore-not-found
   ```

8. **Verify** — no stray `Service` type `LoadBalancer`, no Ingress, no study-platform pods:

   ```bash
   kubectl get ingress,svc,pods -A
   ```

---

## Phase 2–5 — AWS resources (single Terraform destroy)

EKS, RDS, S3, SQS, VPC, and related IAM/Route53/ACM pieces are destroyed together from the dev environment state:

```bash
cd infra/environments/dev
terraform plan -destroy -refresh=false -out=destroy.tfplan
terraform apply destroy.tfplan
```

Non-interactive CI-style (matches `scripts/teardown-aws.sh` after Kubernetes cleanup):

```bash
terraform destroy -refresh=false -auto-approve
```

Use **`-refresh=false`** when Ingress and ALBs are already deleted: the `public_https` module reads ALBs by name (`data "aws_lb"`); a normal refresh would error with “couldn't find resource”. Skipping refresh uses the last state snapshot so Route53 alias records and ACM resources can still be destroyed cleanly.

If destroy fails on VPC/ENI/LB dependencies for other reasons, fix the reported object in the AWS console, then re-run the same command.

---

## Phase 6 — Manual extras (not in Terraform)

- **ECR:** Repositories created per QUICKSTART (`study-platform-api`, `study-platform-worker`) — delete images or repositories if no longer needed.
- **Local kubeconfig** context for the deleted cluster is harmless; remove with `kubectl config delete-context` if desired.

---

## Verification checklist

| Check | Command / expectation |
|--------|------------------------|
| AWS identity | `aws sts get-caller-identity` matches intended account |
| No Ingress | `kubectl get ingress -A` empty (before cluster gone) |
| Terraform clean | `terraform plan` in `infra/environments/dev` shows no changes **after** destroy (empty state or state removed) |
| EKS | No cluster named like `{project}-{env}-eks` |
| RDS | Instance id from `rds_identifier` local gone |
| S3 | Bucket from `submissions_bucket` output gone |
| SQS | Main + DLQ names `{name_prefix}-submissions` and `-submissions-dlq` gone |

---

## One-command script (after Phase 0 env vars and review)

For automation, use [scripts/teardown-aws.sh](../scripts/teardown-aws.sh) from the repo root: `bash scripts/teardown-aws.sh` (non-interactive `terraform destroy`).
