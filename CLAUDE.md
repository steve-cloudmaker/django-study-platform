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