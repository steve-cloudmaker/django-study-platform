# ADR-0006: Grafana Anonymous Viewer Access for Embedding

- **Date:** 2026-04-30
- **Status:** Accepted (dev access model)

## Context

The frontend embeds Grafana dashboards in an iframe for immediate operational visibility.

## Decision

Enable Grafana anonymous access with Viewer role and allow embedding.

## Rationale

- Removes login friction for dashboard consumption in embedded UI.
- Simplifies operational access in controlled environment.

## Consequences

- **Positive:** Fast visibility and smoother in-app observability UX.
- **Negative:** Broader exposure risk if network restrictions are widened.

## Follow-up

- Keep strict ingress CIDR restrictions in dev.
- Evaluate SSO/authenticated proxy model for broader production use.
