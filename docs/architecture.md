# IOTA — System Architecture

> Draft reconstructed from the HackNova build playbook. Review and edit
> with your teammates before treating this as frozen — this is a starting
> point for Block 0, not a substitute for actually agreeing on it.

## 1. What IOTA is

A civic issue-reporting system. Citizens report issues (photo + location +
category) via web or Android. The system routes each issue to the right
ward/department, deduplicates near-identical reports, scores severity, and
gives officers a queue to triage and resolve them. Citizens see status
progress through to resolution.

## 2. Services (backend/services/)

| Service | Owns | Talks to |
|---|---|---|
| `gateway` | Public API surface (BFF), auth verification, routing to internal services | All services, both web apps, Android |
| `identity-service` | User records, role assignment (citizen/officer/admin), Firebase UID sync | `gateway`, `shared/db` |
| `issue-service` | Issue CRUD, status lifecycle, upvotes, escalations | `gateway`, `shared/db`, queue (produces routing/dedup jobs) |
| `routing-service` | Consumes ML results, applies ward/department assignment to issues | queue, `shared/db` |
| `notification-service` | Status-change notifications to citizens | `issue-service` events, (push/SMS provider TBD) |
| `ml-service` (Python) | Consumes `RoutingJobPayload`/`DedupJobPayload`, runs image hashing + embeddings + geo logic, publishes results back | queue only — no direct DB writes outside its own read path |

Each service boots standalone for local dev, is called through `gateway`
in prod. This is the seam that lets Track A code stay in one head without
one giant monolith.

## 3. Core data entities (backend/shared/db)

- **User** — id, role (citizen/officer/admin), Firebase UID, profile fields
- **Ward** — id, name, boundary (GeoJSON/geometry polygon)
- **Issue** — id, category, description, location (geography Point),
  status, ward_id, department_id, severity_score, duplicate_of_issue_id,
  reporter_id, client_uuid (idempotency key), sla_due_at
- **StatusHistory** — issue_id, from_status, to_status, actor_id, note,
  optional photo, timestamp
- **Upvote** — issue_id, user_id (citizen corroboration signal)
- **Escalation** — issue_id, reason, triggered_at (e.g. SLA breach)
- **Department** — id, name, ward mappings

Indexes to freeze early: GIST on `Issue.location`, composite on
`(ward_id, status)`, index on `sla_due_at`.

## 4. Status lifecycle (enforced server-side in `issue-service`)

```
Reported → Acknowledged → In Progress → Resolved → Verified
```

Illegal jumps are rejected. Every transition writes a `StatusHistory` row.
`Resolved` requires an after-photo — enforced server-side, not just in UI.

## 5. Async flow: issue → routing/dedup → back to issue

1. Citizen (web or Android) submits an issue → `issue-service` writes the
   row, enqueues `RoutingJobPayload` and `DedupJobPayload`.
2. `ml-service` consumes both jobs off the queue, does perceptual-hash +
   embedding similarity for dedup, geo lookup for ward/department routing,
   and a severity score.
3. `ml-service` publishes results back via the callback contract
   (`SeverityUpdatePayload`-shaped) — `ward_id`/`department_id` assignment,
   `duplicate_of_issue_id` if applicable, `severity_score`.
4. `issue-service`/`routing-service` applies the update to the issue row.
5. If the queue is down at submission time, issue creation still succeeds
   (graceful degradation) — a sweep job picks up unrouted issues later.

This queue boundary is the parallelization seam between Track A and
Track B — neither blocks on the other once the event schemas are frozen.

## 6. Client apps

- **web/citizen-app** (React/Vite) — report, track, view own issues on a
  map. UI designed separately in Google Stitch, then integrated (not
  copy-pasted) into real routes/state/API calls.
- **web/admin-console** (React/Vite) — officer/admin triage queue, case
  detail, analytics. Same Stitch-then-integrate approach.
- **mobile/android** (Kotlin) — same core loop as citizen-app: submit,
  track, offline-first via Room + WorkManager background sync. Talks to
  the system only through `gateway`'s REST API — never touches the DB or
  queue directly.

## 7. Auth

Firebase Auth: phone OTP for citizens, email/Google for officer/admin.
`gateway` verifies ID tokens; RBAC enforced server-side only (never
trust a client-asserted role). Officer/admin roles are never
self-assignable via public signup. The exact token header format is
documented in `docs/api-spec.yaml`'s security scheme — this is what
Android's Retrofit client and the web clients both read, so it must be
frozen before Track C starts its auth block.

## 8. Idempotency

Every issue submission carries a client-generated UUID, persisted locally
before any network call (Room on Android, IndexedDB/localStorage on web).
Resubmitting the same draft after a partial failure reuses the same UUID —
the server treats a repeated UUID as "return the existing issue," never
a new row. This is the mechanism that makes offline-first sync safe on
both platforms.

## 9. Infra (local dev)

Docker Compose: PostgreSQL + PostGIS, Redis, RabbitMQ (or BullMQ-on-Redis —
Track A decides and states why in Block A1), MinIO (S3-compatible fallback
if Cloudinary's free tier is unavailable during dev).

## 10. Deploy target

Railway for backend + web. ML service as its own Railway service, or a
small always-on box if free-tier queue connectivity to Railway's Redis
turns out to be a problem — flag this early if so, don't discover it near
the deadline.