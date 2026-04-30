# ADR-0001: EKS Managed Node Groups

- **Date:** 2026-04-30
- **Status:** Accepted

## Context

The platform requires a production-capable orchestrator with autoscaling and AWS-native integration for identity and ingress.

## Decision

Run workloads on EKS using managed node groups.

## Rationale

- Native support for Kubernetes control loops and declarative rollout patterns.
- Direct compatibility with IRSA and AWS Load Balancer Controller.
- Operationally consistent model for API, worker, frontend, and observability services.

## Consequences

- **Positive:** Strong operational baseline, standardized scaling/deployment model.
- **Negative:** Higher complexity and baseline cost than VM-only patterns.

## Follow-up

- Maintain addon/Kubernetes upgrade runbook and test upgrade paths regularly.
