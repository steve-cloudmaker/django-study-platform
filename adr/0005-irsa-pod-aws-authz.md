# ADR-0005: IRSA for Pod-to-AWS Authorization

- **Date:** 2026-04-30
- **Status:** Accepted

## Context

Workloads require AWS API access (S3, SQS, ELB/EC2 management for controller) without static credentials.

## Decision

Use IAM Roles for Service Accounts (IRSA) with OIDC trust per Kubernetes service account.

## Rationale

- Least-privilege role separation for API, worker, and ALB controller.
- Avoids static credential injection into containers.
- Improves auditability of AWS API usage.

## Consequences

- **Positive:** Strong credential hygiene and reduced blast radius.
- **Negative:** More IAM/OIDC and policy maintenance complexity.

## Follow-up

- Periodically review policy scope against observed CloudTrail access patterns.
