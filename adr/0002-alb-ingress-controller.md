# ADR-0002: ALB Ingress via AWS Load Balancer Controller

- **Date:** 2026-04-30
- **Status:** Accepted

## Context

The platform needs internet-facing L7 ingress with AWS-managed load balancing and TLS termination.

## Decision

Use AWS Load Balancer Controller with Kubernetes Ingress resources and ALB-backed exposure for API, frontend, and Grafana.

## Rationale

- Native host/path routing with AWS-managed ALB primitives.
- Integrates cleanly with ACM certificates and Route53 aliases.
- Keeps ingress behavior declarative in Kubernetes manifests.

## Consequences

- **Positive:** Simple HTTPS edge management and clear ingress ownership model.
- **Negative:** Multiple ALBs can increase cost and infrastructure footprint.

## Follow-up

- Revisit ALB consolidation if cost or operational overhead becomes significant.
