# CLAUDE.md

## Purpose
This document guides AI assistants (Claude, ChatGPT, etc.) to behave as a **senior SRE + backend engineer** while helping build the Resilient Study Platform.

---

## Core Principles

### 1. Prioritize SRE Signal Over Feature Depth
- Always prefer reliability, observability, and scalability decisions over product complexity
- Avoid unnecessary features (auth complexity, UI polish, etc.)

### 2. Default Architecture
- Backend: Django + Django REST Framework
- Frontend: Next.js (SPA)
- Infrastructure: AWS (EKS-first)
- Queue: SQS
- Database: PostgreSQL (RDS)
- Storage: S3

---

## Coding Guidelines

### Backend (Django)
- Use Django REST Framework for APIs
- Keep views thin, push logic to services
- All submission flows must be async via SQS
- Return HTTP 202 for async operations

### Worker Design
- Idempotent processing
- Retry-safe
- Log all failures with context

### Logging
- Structured JSON logs
- Include:
  - request_id
  - study_id
  - submission_id

---

## Observability Requirements

Every service must expose:
- Request count
- Request latency
- Error rate

Workers must expose:
- Job processing time
- Failure count

---

## Infrastructure Rules

- Use Terraform for all AWS resources
- Use EKS (no EC2-only deployments)
- Use SQS (not Redis queues)
- Use IAM roles (no hardcoded credentials)

---

## What NOT to Build

- Complex authentication systems
- Over-engineered schemas
- Kafka (use SQS)
- Service mesh

---

## Expected Behavior from AI Assistants

When suggesting solutions:
- Prefer simplest viable architecture
- Explain tradeoffs briefly
- Optimize for implementation speed
- Keep outputs concise and production-oriented

---


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

1. Provision infrastructure with Terraform
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


# INFRA_SPEC.md

## Overview

This document defines the AWS infrastructure for the Resilient Study Platform.

---

## Core Services

### Compute
- EKS Cluster
  - API Deployment (Django)
  - Worker Deployment

---

### Networking
- VPC
- Public subnets (ALB)
- Private subnets (EKS, RDS)
- Application Load Balancer (ALB)

---

### Data Layer
- RDS PostgreSQL
- S3 bucket (raw submissions)

---

### Messaging
- SQS Queue
- Dead Letter Queue (DLQ)

---

### Observability
- CloudWatch (logs + metrics)
- Prometheus (metrics scraping)
- Grafana (dashboard visualization)

---

## IAM

- IAM roles for:
  - EKS nodes
  - API service
  - Worker service

- Permissions:
  - S3 read/write
  - SQS send/receive
  - CloudWatch logs

---

## Scaling Strategy

### API
- Horizontal Pod Autoscaler (CPU or request-based)

### Workers
- Scale based on queue depth
- Optional: KEDA for event-driven scaling

---

## Data Flow

1. Client sends submission
2. API stores payload in S3
3. API sends message to SQS
4. Worker consumes message
5. Worker processes and writes to RDS

---

## Failure Handling

- Retries via SQS
- Failed messages routed to DLQ

---

## Security

- No public DB access
- IAM roles instead of static credentials
- HTTPS via ALB

---

## Terraform Structure

```
infra/
  modules/
    vpc/
    eks/
    rds/
    s3/
    sqs/
    iam/
    alb/
  environments/
    dev/
      main.tf
```

---

## Deployment Flow

1. terraform apply
2. build + push Docker images to ECR
3. deploy via kubectl or Helm

---

## Future Enhancements

- CloudFront CDN
- Multi-region failover
- Blue/green deployments
- Service mesh (if needed)

