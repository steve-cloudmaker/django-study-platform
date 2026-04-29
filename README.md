# README.md

## Resilient Study Platform

A reliability-focused study collection system designed to demonstrate **SRE best practices** including:
- Asynchronous processing
- Backpressure handling
- Observability (metrics + dashboards)
- Scalable infrastructure on AWS

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
- Prometheus metrics
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
4. Deploy to EKS

---

## Observability

Grafana dashboards include:
- API latency (p95)
- Request rate
- Error rate
- Queue depth
- Worker throughput

---

## Future Enhancements

- CDN via CloudFront
- Autoscaling via KEDA
- Advanced analytics
- Multi-region deployment

---