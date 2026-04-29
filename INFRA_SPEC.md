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