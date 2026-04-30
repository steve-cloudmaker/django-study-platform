# ADR-0004: Asynchronous Submission Pipeline (S3 + SQS + Worker)

- **Date:** 2026-04-30
- **Status:** Accepted (worker logic pending full implementation)

## Context

Submission traffic should not couple user request latency to downstream processing latency.

## Decision

Use an asynchronous flow:
1. API stores payload/object in S3.
2. API enqueues metadata/work item into SQS.
3. Worker consumes queue and processes asynchronously.

## Rationale

- Better resilience under bursts and transient downstream failures.
- Supports retry and dead-letter patterns.
- Reduces synchronous API latency pressure.

## Consequences

- **Positive:** Improved fault isolation and backpressure handling.
- **Negative:** Eventual consistency and worker correctness become critical.

## Follow-up

- Replace worker stub with production queue consumer implementation (idempotency, retries, failure instrumentation).
