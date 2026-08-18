# IOTA Contract Summary — Sign-off Document

> **Status: AWAITING SIGN-OFF from all three team members before any Track (A, B, C) starts its first block.**
> Once signed off and committed, changing anything below is a cross-team event requiring coordination across all tracks.

---

## 1. Auth — Token Contract (highest-risk drift point)

| Concern | Frozen value |
|---|---|
| Header name | `Authorization` (capital A — standard HTTP header) |
| Header format | `Authorization: Bearer <firebase-id-token>` |
| Token source | Firebase client SDK: `getIdToken(true)` |
| Android call | `FirebaseAuth.getInstance().currentUser!!.getIdToken(true).await().token` |
| Web call | `getAuth().currentUser?.getIdToken(true)` |
| Token format | Raw JWT string — **no Base64 re-encoding, no custom prefix** |
| Server verification | `firebase-admin` `verifyIdToken(token)` in gateway middleware |
| Token lifetime | 3600 s (1 hour) |
| Refresh endpoint | `POST /v1/auth/refresh` with `{ "refresh_token": "..." }` |
| Role source of truth | DB `users.role` column — **never trust client-asserted role** |

---

## 2. API Endpoints (`docs/api-spec.yaml`)

Base URL: `https://api.iota.app/v1` (prod) · `http://localhost:4000/v1` (local)

### Auth
| Method | Path | Auth | Notes |
|---|---|---|---|
| `POST` | `/auth/token` | None | Exchange Firebase ID token → role + expiry metadata |
| `POST` | `/auth/refresh` | None | Refresh Firebase ID token via refresh_token |

### Users
| Method | Path | Auth | Notes |
|---|---|---|---|
| `GET` | `/users/me` | Bearer | Current user's profile |
| `PATCH` | `/users/me` | Bearer | Update display_name only |

### Media
| Method | Path | Auth | Notes |
|---|---|---|---|
| `POST` | `/media/upload` | Bearer | Get pre-signed PUT URL for photo; upload directly, then pass `public_url` to issue create |

### Issues (core CRUD)
| Method | Path | Auth | Roles | Notes |
|---|---|---|---|---|
| `POST` | `/issues` | Bearer | CITIZEN | Idempotent via `client_uuid`; 201=new, 200=existing |
| `GET` | `/issues` | Bearer | ALL | Citizens see own; officers see ward; admins see all |
| `GET` | `/issues/{id}` | Bearer | ALL | Full detail incl. ML-assigned fields |
| `PATCH` | `/issues/{id}/status` | Bearer | OFFICER, ADMIN | Enforces state machine; `after_photo_url` required for RESOLVED |
| `GET` | `/issues/{id}/history` | Bearer | ALL | Ordered list of status transitions |
| `POST` | `/issues/{id}/upvote` | Bearer | CITIZEN | Idempotent; citizens cannot upvote own issues |
| `DELETE` | `/issues/{id}/upvote` | Bearer | CITIZEN | Idempotent |

### Officer Queue
| Method | Path | Auth | Roles | Notes |
|---|---|---|---|---|
| `GET` | `/officer/queue` | Bearer | OFFICER, ADMIN | Sorted by composite priority_score; excludes RESOLVED/VERIFIED |

### Reference Data
| Method | Path | Auth | Notes |
|---|---|---|---|
| `GET` | `/wards` | Bearer | All wards (incl. boundary GeoJSON) |
| `GET` | `/wards/{id}` | Bearer | Single ward |
| `GET` | `/departments` | Bearer | All departments |

### Admin (`x-status: planned`)
| Method | Path | Auth | Notes |
|---|---|---|---|
| `GET` | `/admin/users` | Bearer (ADMIN) | Paginated user list, filterable by role |
| `PUT` | `/admin/users/{id}/role` | Bearer (ADMIN) | Assign role; officer role requires `ward_id` |
| `GET` | `/admin/analytics` | Bearer (ADMIN) | Issue counts + avg resolution hours by period / ward |

---

## 3. Status Lifecycle (server-enforced)

```
REPORTED → ACKNOWLEDGED → IN_PROGRESS → RESOLVED → VERIFIED
```

- **Illegal jumps** → `422 ILLEGAL_TRANSITION`
- **Every transition** → writes `status_history` row + triggers notification
- **RESOLVED** → requires `after_photo_url` (enforced server-side)

---

## 4. Idempotency Contract

- Every issue submission carries a **client-generated `client_uuid`** (UUID v4)
- Persisted locally **before** the network call (Room on Android, IndexedDB on web)
- Resubmitting same `client_uuid` → server returns **HTTP 200** + existing issue body (never a duplicate row)
- DB unique constraint: `(reporter_id, client_uuid)`

---

## 5. Queue Event Schemas (`backend/shared/libs/event-schemas/`)

### Queue names
| Queue | Direction | Payload |
|---|---|---|
| `routing_jobs` | backend → ml-service | `RoutingJobPayload` |
| `dedup_jobs` | backend → ml-service | `DedupJobPayload` |
| `ml_results` | ml-service → backend | `SeverityUpdatePayload` |

### RoutingJobPayload
```jsonc
{
  "job_type": "routing_job",               // string literal
  "issue_id": "c3d4e5f6-...",              // UUID
  "category": "ROAD_DAMAGE",              // IssueCategory enum
  "latitude": 18.5204,                    // float, [-90, 90]
  "longitude": 73.8567,                   // float, [-180, 180]
  "enqueued_at": "2026-02-15T10:00:00Z"  // ISO-8601 datetime
}
```

### DedupJobPayload
```jsonc
{
  "job_type": "dedup_job",
  "issue_id": "c3d4e5f6-...",
  "category": "ROAD_DAMAGE",
  "latitude": 18.5204,
  "longitude": 73.8567,
  "photo_urls": ["https://cdn.iota.app/issues/photo_abc123.webp"],  // may be []
  "description": "Large pothole near Shivaji Market.",
  "enqueued_at": "2026-02-15T10:00:00Z"
}
```

### SeverityUpdatePayload (ml-service → backend)
```jsonc
{
  "job_type": "severity_update",
  "issue_id": "c3d4e5f6-...",
  "severity_score": 0.73,                   // float [0,1] or null
  "ward_id": "d4e5f6a7-...",               // UUID or null
  "department_id": "e5f6a7b8-...",         // UUID or null
  "duplicate_of_issue_id": null,           // UUID or null
  "image_phash": "a1b2c3d4e5f60718",       // hex string or null
  "dedup_confidence": null,                // float [0,1] or null
  "processed_at": "2026-02-15T10:01:30Z"
}
```

**Critical:** Field names above are **identical** between TypeScript (`index.ts`) and Python (`schemas.py`). Verified by automated check — zero field mismatches.

---

## 6. Database Tables (`backend/shared/db/migrations/0001_init.sql`)

### Table: `users`
| Column | Type | Notes |
|---|---|---|
| `id` | `UUID PK` | Internal ID |
| `firebase_uid` | `TEXT UNIQUE NOT NULL` | Raw Firebase UID from ID token |
| `role` | `user_role` enum | `CITIZEN` / `OFFICER` / `ADMIN` |
| `display_name` | `TEXT NOT NULL` | |
| `phone_number` | `TEXT NULL` | E.164, citizens only |
| `email` | `TEXT NULL` | Officers/admins |
| `ward_id` | `UUID NULL → wards` | Officers only |
| `created_at` / `updated_at` | `TIMESTAMPTZ` | Auto-managed |

### Table: `wards`
| Column | Type | Notes |
|---|---|---|
| `id` | `UUID PK` | |
| `name` | `TEXT NOT NULL` | e.g. "Ward 14 - Shivajinagar" |
| `boundary` | `geometry(Polygon, 4326)` | WGS-84 polygon; GIST index deferred to 0002 |
| `created_at` / `updated_at` | `TIMESTAMPTZ` | |

### Table: `departments`
| Column | Type | Notes |
|---|---|---|
| `id` | `UUID PK` | |
| `name` | `TEXT NOT NULL` | e.g. "Roads and Infrastructure" |
| `created_at` / `updated_at` | `TIMESTAMPTZ` | |

### Table: `issues`
| Column | Type | Notes |
|---|---|---|
| `id` | `UUID PK` | |
| `client_uuid` | `UUID NOT NULL` | Idempotency key from client |
| `reporter_id` | `UUID → users` | |
| `category` | `issue_category` enum | |
| `description` | `TEXT NOT NULL` | |
| `location` | `geography(Point, 4326)` | WGS-84 point; GIST index deferred to 0002 |
| `address_hint` | `TEXT NULL` | Reverse-geocoded, client-supplied |
| `photo_urls` | `JSONB NOT NULL DEFAULT '[]'` | Array of CDN URL strings |
| `status` | `issue_status` enum | Default `REPORTED` |
| `ward_id` | `UUID NULL → wards` | Set by routing-service after ML |
| `department_id` | `UUID NULL → departments` | Set by routing-service after ML |
| `severity_score` | `NUMERIC(4,3) NULL` | [0,1]; set by ml-service |
| `duplicate_of_issue_id` | `UUID NULL → issues` | Set by ml-service if duplicate |
| `image_phash` | `TEXT NULL` | pHash hex from ml-service |
| `sla_due_at` | `TIMESTAMPTZ NULL` | |
| `created_at` / `updated_at` | `TIMESTAMPTZ` | |

Unique index: `(reporter_id, client_uuid)` · Partial index: `(ward_id, status)` · SLA partial index: `(sla_due_at)` where active

### Table: `status_history`
| Column | Type | Notes |
|---|---|---|
| `id` | `UUID PK` | |
| `issue_id` | `UUID → issues` | CASCADE delete |
| `from_status` | `issue_status` | |
| `to_status` | `issue_status` | |
| `actor_id` | `UUID → users` | Officer/admin who made the change |
| `note` | `TEXT NULL` | |
| `photo_url` | `TEXT NULL` | Required (app-layer) when `to_status = RESOLVED` |
| `created_at` | `TIMESTAMPTZ` | Immutable — no `updated_at` |

### Table: `upvotes`
| Column | Type | Notes |
|---|---|---|
| `issue_id` | `UUID → issues` | Composite PK |
| `user_id` | `UUID → users` | Composite PK |
| `created_at` | `TIMESTAMPTZ` | |

One upvote per (issue, user) pair enforced by composite PK.

---

## 7. Validation Results

| Check | Result |
|---|---|
| Spectral OpenAPI lint (`docs/api-spec.yaml`) | ✅ **0 errors, 0 warnings** (exit 0) |
| TS ↔ Python field name parity | ✅ **PASS** — all 3 schemas match exactly |
| SQL migration (`0001_init.sql`) | ✅ Static parse validated; Docker not available on dev machine — team to run against PostGIS before merging |

### Spectral output
```
No results with a severity of 'error' found!
Spectral exit: 0
```

### Python schema parity output
```
=== TS vs Python field parity: PASS ===

RoutingJobPayload:
  category:     enum 'IssueCategory'
  enqueued_at:  datetime.datetime
  issue_id:     uuid.UUID
  job_type:     Literal['routing_job']
  latitude:     float
  longitude:    float

DedupJobPayload:
  category:     enum 'IssueCategory'
  description:  str
  enqueued_at:  datetime.datetime
  issue_id:     uuid.UUID
  job_type:     Literal['dedup_job']
  latitude:     float
  longitude:    float
  photo_urls:   List[str]

SeverityUpdatePayload:
  dedup_confidence:       Optional[float]
  department_id:          Optional[uuid.UUID]
  duplicate_of_issue_id:  Optional[uuid.UUID]
  image_phash:            Optional[str]
  issue_id:               uuid.UUID
  job_type:               Literal['severity_update']
  processed_at:           datetime.datetime
  severity_score:         Optional[float]
  ward_id:                Optional[uuid.UUID]
```

> [!IMPORTANT]
> The SQL migration must be run against a live PostGIS 16 instance before the team signs off on this document. Command:
> ```bash
> psql -U postgres -d iota_test -f backend/shared/db/migrations/0001_init.sql
> ```

---

## 8. Files Produced

| File | Purpose |
|---|---|
| [`docs/api-spec.yaml`](file:///d:/Iota/docs/api-spec.yaml) | OpenAPI 3.1 — frozen REST contract (web + Android) |
| [`backend/shared/libs/event-schemas/index.ts`](file:///d:/Iota/backend/shared/libs/event-schemas/index.ts) | Queue payload types (TS source of truth) + JSON Schemas |
| [`backend/services/ml-service/app/schemas.py`](file:///d:/Iota/backend/services/ml-service/app/schemas.py) | Python Pydantic v2 mirror of above |
| [`backend/shared/db/migrations/0001_init.sql`](file:///d:/Iota/backend/shared/db/migrations/0001_init.sql) | Initial DB schema — core 6 tables + enums + triggers |
| [`docs/contract-summary.md`](file:///d:/Iota/docs/contract-summary.md) | This document |

---

## 9. Sign-off

- [ ] **Track A** (Backend + Web): _______________
- [ ] **Track B** (ML Service): _______________
- [ ] **Track C** (Android): _______________

**Do not start Track A1 / B1 / C1 until all three boxes are checked.**
