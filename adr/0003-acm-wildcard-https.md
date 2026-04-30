# ADR-0003: ACM Wildcard Certificate and Enforced HTTPS

- **Date:** 2026-04-30
- **Status:** Accepted

## Context

Public services require secure transport and low-overhead certificate lifecycle management.

## Decision

Use ACM wildcard certificate (`*.charliesystems.ai` + apex) and enforce HTTP-to-HTTPS redirects on ALB listeners.

## Rationale

- Centralized certificate issuance/renewal in AWS.
- No private key material stored in Kubernetes manifests.
- Consistent secure endpoint posture across API, app, and Grafana.

## Consequences

- **Positive:** Strong default transport security and low cert ops burden.
- **Negative:** Requires accurate DNS delegation/validation; duplicate hosted zones can cause drift.

## Follow-up

- Keep `public_hosted_zone_id` explicitly pinned where duplicate zones exist.
