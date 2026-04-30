# ADR-0007: CIDR-Restricted ALB Ingress Access

- **Date:** 2026-04-30
- **Status:** Accepted

## Context

Public ALBs should be tightly scoped while the platform remains in controlled-access mode.

## Decision

Restrict ingress traffic using `alb.ingress.kubernetes.io/inbound-cidrs` (currently `98.51.205.17/32`).

## Rationale

- Minimizes internet exposure surface.
- Quick and effective control without adding extra components.

## Consequences

- **Positive:** Immediate reduction in unauthorized access risk.
- **Negative:** Operational fragility when operator IP changes; requires disciplined update process.

## Follow-up

- Externalize and automate allowlist updates for operator/CI access patterns.
