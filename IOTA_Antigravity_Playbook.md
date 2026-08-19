# IOTA — HackNova 2026 — Parallel Antigravity Build Playbook

**Team size:** 3, working fully in parallel from hour 1.
**Split:** (1) Backend + Web, (2) ML Service, (3) Android.
**Contract-first:** nobody blocks on anybody because the OpenAPI spec and shared types are frozen in Block 0 and everyone codes against *that*, not against each other's live server.
**Frontend note:** Web UI is designed in **Google Stitch** (prompted separately, exported as React/HTML), then an Antigravity task *stitches it into* the real app — it wires Stitch's static components to real API calls, state, and routing. Stitch output is treated as a design/markup source, never as the final component tree.

---

## 0. Why this split

Looking at the repo tree you pasted:

- `gateway/`, `services/issue-service`, `services/identity-service`, `services/routing-service`, `services/notification-service`, `shared/db`, `web/citizen-app`, `web/admin-console` are all Node/TS and all CRUD-and-glue heavy → one person, because context-switching between them is cheap (same language, same DB, same repo) and splitting them across people would mean constant merge conflicts on `shared/`. This is your "backend is simpler, give it to the web person" instinct, and it's correct engineering, not a shortcut: these pieces share types and a database, so keeping them in one head reduces integration risk more than it costs in raw hours.
- `services/ml-service` is Python, has its own dependency stack (image hashing, embeddings, ONNX), and only talks to the rest of the system through a queue contract (`consumer.py` reads jobs, writes results back). That queue boundary is a clean parallelization seam → its own person.
- `mobile/android` is Kotlin, has its own build toolchain (Gradle), its own local DB (Room), and only talks to the rest of the system through the REST API → another clean seam → its own person.

Each of the three tracks below is written as a **self-contained Antigravity prompt playbook**, same discipline as your CivicTrack doc: one block per agent task, tests before "done," commit message given, Artifact you personally check before moving to the next block. Do **not** paste a whole track into one mega-prompt for the same token/reviewability reasons as before.

---

## 1. One-time setup (all three people, together, before anyone opens Antigravity) — ~30 min

1. Create the GitHub repo `iota`, structure it exactly as in your tree. Push the empty skeleton folders with `.gitkeep` so paths exist.
2. **Freeze the contract first.** Before any track writes a line of feature code, one of you (suggest: backend person) runs a single Antigravity task to produce:
   - `docs/api-spec.yaml` — OpenAPI 3.1 spec for every endpoint used by web *and* Android (auth, issue CRUD, upvote, status transitions, officer queue). Even fields that don't exist server-side yet go in as documented-but-not-yet-implemented (mark with `x-status: planned`).
   - `backend/shared/libs/event-schemas/` — the job payload contracts the ML service will read from and write to the queue (`RoutingJobPayload`, `DedupJobPayload`, `SeverityUpdatePayload`), as JSON Schema or TS types, mirrored as a Python `TypedDict`/Pydantic model in `services/ml-service/app/schemas.py`.
   - `backend/shared/db/migrations/0001_init.sql` — the core tables (`users`, `issues`, `status_history`, `upvotes`, `wards`, `departments`) so Android and ML can see real column names instead of guessing.
   This is the single most important artifact in the whole build — **everyone reviews and signs off on it before splitting up.** Changing it later costs all three tracks time; freezing it wrong costs less than freezing it late.
3. Each track gets its own `.agents/skills/<track>-conventions.md` (contents below, per track) — this is what stops Antigravity from "helpfully" reinventing your stack mid-task, same trick as the CivicTrack doc.
4. Agree on the integration checkpoints in advance (see §5) and put them on a shared clock — hackathons die from three perfect components that don't fit together at hour 30.
5. Set Agent Manager to **Planning mode ON** for every block in every track below.

---

## 2. Track A — Backend + Web (owner: the "web/backend" person)

### `.agents/skills/backend-web-conventions.md`
```
Stack: Node.js + TypeScript (strict) + NestJS (gateway + all services) + PostgreSQL/PostGIS
       (via Prisma) + Redis/BullMQ + Docker Compose + Firebase Auth + Cloudinary
       + React/Vite (web/citizen-app, web/admin-console) + Leaflet/OpenStreetMap.
Do not swap in AWS/S3/Mongo/Express/Mapbox. Do not restructure the /backend or /web
folder layout given in docs/architecture.md without asking.
Coding: ESLint + Prettier, conventional commits, commented code (portfolio-grade,
not CP-style golf).
Testing bar: every block ships with passing Jest unit tests for logic and at least
one integration test for new/changed API routes before being marked done.
Contract: docs/api-spec.yaml and backend/shared/libs/event-schemas/ are the source
of truth. If a block needs to deviate from them, stop and flag it — don't silently
diverge, the ML and Android tracks are coding against the frozen version.
```

### Block A1 — Monorepo skeleton + infra
```
Read docs/architecture.md and docs/api-spec.yaml for context only — do not build
features yet.

Set up the backend + web portion of the IOTA monorepo per the given file tree:
- backend/gateway (NestJS API gateway/BFF)
- backend/services/issue-service, identity-service, routing-service,
  notification-service (NestJS, each its own package.json, boots standalone
  for local dev, called through the gateway in prod)
- backend/shared/db (migrations/, seed/) and backend/shared/libs (auth-lib,
  geo-lib, event-schemas already frozen in Block 0 — do not regenerate them)
- docker-compose.yml: Postgres+PostGIS, Redis, RabbitMQ (or BullMQ-on-Redis if
  you judge RabbitMQ redundant — state which you chose and why), MinIO
  (local S3-compatible store, used only if Cloudinary free tier is unavailable
  during dev), all with healthchecks
- web/citizen-app and web/admin-console: Vite + React placeholder pages that boot

Requirements:
- Each backend service exposes GET /health returning 200
- Root README with setup instructions
- .env.example in each service/app, no real secrets
- ESLint + Prettier + TS strict shared at the root

Testing before done:
1. docker compose up -d — confirm every container healthy
2. curl /health on gateway and each service, confirm 200
3. Boot both web apps, screenshot artifact of each placeholder loading
4. Lint the whole repo, zero errors

Commit as: "chore: monorepo scaffold + local infra"
```

### Block A2 — Database schema + PostGIS + seed data
```
Implement the frozen data model from backend/shared/db/migrations/0001_init.sql
using Prisma against PostgreSQL + PostGIS. Extend with the full entity set from
docs/architecture.md: User, Ward (GeoJSON boundary, geometry type), Issue
(geography(Point) location, GIST index), StatusHistory, Upvote, Escalation,
Department.

Requirements:
- Proper migration files, not schema push
- GIST index on Issue.location, composite index on (ward_id, status), index on
  sla_due_at
- Seed script: 3-5 fake ward polygons (simple rectangles, plausible not real),
  2 departments, a few test users per role (citizen/officer/admin)
- Seed idempotency check (running twice doesn't duplicate)

Testing before done:
1. Run migrations against dockerized Postgres, no errors
2. Run seed, psql row counts pasted as proof
3. Jest integration test: ST_DWithin proximity query against seeded issues
4. \d+ output on issue table confirming indexes, pasted

Commit as: "feat: database schema, migrations, PostGIS indexes, seed data"
```

### Block A3 — Auth (Firebase) + RBAC
```
Implement auth in the gateway using Firebase Auth (phone OTP for citizens,
email/Google for officer/admin).

Requirements:
- NestJS guard verifying Firebase ID tokens on protected routes
- RBAC middleware: citizen/officer/admin enforced server-side only
- Auto-create User row on first login, synced to Firebase UID
- Officer/admin roles never self-assignable via public signup — admin-only
  endpoint or manual seed only
- Wire Firebase SDK into web/citizen-app: phone OTP login screen
- Emit an identical Retrofit-friendly token contract Android will use later
  (document the exact header format in docs/api-spec.yaml security scheme —
  Android track reads this, doesn't guess it)

Testing before done:
1. Unit tests: valid token passes, expired/invalid → 401, wrong role → 403
2. Integration test: citizen token can't hit officer-only endpoint
3. Screenshot artifact: successful login flow against a real test Firebase project
4. Confirm .gitignore covers the Firebase admin SDK key — no secrets committed

Commit as: "feat: Firebase auth + RBAC guards"
```

### Block A4 — Citizen submit flow (core loop)
```
Build the citizen issue-submission flow end to end: photo + geotag + category +
description → API → DB → Cloudinary. This is the endpoint Android will also hit —
match docs/api-spec.yaml exactly, field for field.

API:
- POST /issues — category, description, lat/lng, client-generated UUID
  (idempotency key), photo upload; photo → Cloudinary, store URL not binary
- Idempotent: same client UUID twice → returns existing issue, no duplicate row
- GET /issues/:id, GET /issues (paginated, filterable by status/ward)

Web (citizen-app placeholder form for now — real UI lands in Block A7 via Stitch):
- Minimal functional form: photo capture/upload, browser geolocation, category
  dropdown, description
- Optimistic UI: "submitted" state immediately, reconcile with server response

Testing before done:
1. Integration test: POST /issues creates a row with correct geography point
2. Integration test: same client UUID twice → one row, second call 200 + existing
   issue
3. Integration test: missing required field → 400 with clear message
4. Browser-agent artifact: recording of the submit flow, photo through detail page
5. Confirm Cloudinary upload against a real free-tier account, paste returned URL

Commit as: "feat: citizen issue submission flow (photo, geotag, idempotent create)"
```

### Block A5 — Officer console: triage + status lifecycle
```
API additions:
- GET /officer/queue — issues in the officer's ward, filterable/sortable
- PATCH /issues/:id/status — enforce Reported → Acknowledged → In Progress →
  Resolved → Verified, reject illegal jumps
- Every transition writes a StatusHistory row (who, when, note, optional photo)
- "Resolved" REQUIRES an after-photo, enforced server-side

Officer UI (basic, inside admin-console or its own bundle if lighter — your call,
state which):
- Queue list, status update flow, after-photo upload on resolve

Testing before done:
1. Unit test: state machine rejects illegal transitions, accepts legal ones
2. Integration test: "Resolved" without photo → 400
3. Integration test: StatusHistory row created on every transition
4. Browser-agent artifact: full officer flow — queue → acknowledge → progress →
   resolve with photo

Commit as: "feat: officer console — triage queue and enforced status lifecycle"
```

### Block A6 — Queue integration point for the ML service (routing + dedup consumer wiring)
```
This block does NOT implement routing/dedup logic — the ML track owns that. This
block builds the producer side and the contract, so both tracks can develop and
test independently against a real (empty-worker) queue.

Requirements:
- On issue creation, enqueue a routing job (payload per
  backend/shared/libs/event-schemas/RoutingJobPayload) and a dedup job
  (DedupJobPayload) to the queue the ML service consumes from
- Build the callback/consumer endpoint or queue topic the ML service publishes
  results BACK to (ward_id/department assignment, duplicate_of_issue_id,
  severity_score) — this must exist and be testable even with a stub worker
- Graceful degradation: if the queue is down, issue creation still succeeds; a
  sweep job (stub is fine here, full impl in a later block) can pick it up later
- Write a fake/stub consumer in this repo purely for testing this block in
  isolation (temporary — real one lands from the ML track's own repo/service)

Testing before done:
1. Integration test: issue creation enqueues both jobs with correct payload shape
   matching the frozen schema
2. Integration test: kill Redis/RabbitMQ mid-test, issue creation still succeeds
3. Integration test: posting a result back through the callback endpoint updates
   ward_id/department/severity_score on the issue
4. Paste queue dashboard/log output as Artifact

Commit as: "feat: async job producer + ML result callback contract"
```

### Block A7 — Stitch UI integration (citizen-app + admin-console)
```
Design has been produced separately in Google Stitch (exported React/HTML/CSS
components + assets, dropped into /web/_stitch-export/citizen-app and
/web/_stitch-export/admin-console — do not build UI from scratch here).

Task: integrate the Stitch export into the real app, do not just copy-paste it in.
- Map each Stitch screen to the real route/page it belongs to (Home, ReportIssue,
  MyReports, IssueDetail, Profile for citizen-app; Dashboard, CaseQueue,
  CaseDetail, Analytics for admin-console)
- Replace Stitch's static/mock data with real API calls via the existing
  api/client.ts
- Preserve Stitch's visual design (spacing, colors, components) but convert to
  the project's actual component structure, state management, and routing —
  Stitch output is markup reference, not final code
- Wire the forms already built in Block A4/A5 behind the new Stitch-styled UI —
  functionality must not regress
- Re-check accessibility basics (labels, contrast) since generated UI sometimes
  skips these

Testing before done:
1. Every route from Block A4/A5's functional flow still passes its existing
   integration tests, now through the new UI
2. Browser-agent artifact: recording of the full citizen submit flow AND officer
   triage flow on the restyled UI
3. Visual diff/screenshot artifact comparing final app to the Stitch mockups —
   flag any meaningful deviation and explain why

Commit as: "feat: integrate Stitch UI into citizen-app and admin-console"
```

### Block A8 — Rate limiting, offline queue (citizen-app PWA), hardening
```
Requirements:
- Citizen web app: PWA service worker, IndexedDB local queue for offline
  submissions, background sync on reconnect using the same idempotent UUID
  from Block A4
- Rate limiting on POST /issues (NestJS throttler, per-user and per-IP)
- Basic content moderation stub on photo upload (size/type check + documented
  hook for a real moderation API later)
- GitHub Actions CI: lint + test on every PR, build check for gateway + all
  services + both web apps

Testing before done:
1. Manual: DevTools offline, submit, reconnect, confirm single sync, no dupes
2. Integration test: rate limiter returns 429 past threshold
3. CI artifact: green Actions run on the PR for this block

Commit as: "feat: offline sync (web), rate limiting, CI pipeline"
```

---

## 3. Track B — ML Service (owner: the ML person)

### `.agents/skills/ml-service-conventions.md`
```
Stack: Python (FastAPI) + ONNX runtime for served models + a perceptual-hash
library (e.g. imagehash) + CLIP-style embedding model for similarity + geo
utilities (shapely/geopandas is fine locally; do not add a second DB — read/write
through the shared Postgres via the connection details in .env.example).
Do not swap the queue library, do not restructure services/ml-service.
Contract: backend/shared/libs/event-schemas/ (mirrored as Pydantic models in
services/ml-service/app/schemas.py) is the source of truth for job payloads in
and result payloads out. If you need a field that isn't in the frozen schema,
stop and flag it to Track A instead of inventing one — Android/web are also
coding against that contract.
Testing bar: pytest for every module, with fixture data for images so tests are
reproducible without network calls.
```

### Block B1 — Service skeleton + queue consumer plumbing
```
Read backend/shared/libs/event-schemas/ for the frozen job/result payload shapes.
Do not build model logic yet.

Set up services/ml-service:
- app/main.py — FastAPI app with GET /health
- app/consumer.py — connects to the same queue Track A's Block A6 producer
  writes to, consumes RoutingJobPayload and DedupJobPayload messages
- app/schemas.py — Pydantic mirrors of the frozen TS event schemas (must match
  field-for-field; write a test that round-trips a sample payload through both
  and diffs them if both are available, otherwise just assert your schema
  against the documented JSON Schema in the repo)
- requirements.txt, Dockerfile for the service
- models/ directory placeholder with a README on where trained weights go

Testing before done:
1. Service boots, /health returns 200
2. Consumer connects to the queue (point it at Track A's dev Docker Compose queue
   or your own local Redis/RabbitMQ instance running the same image — document
   which), consumes a manually-published test message, logs it correctly
3. Pydantic schema validation test against a sample payload matching the frozen
   contract, including a deliberately malformed payload that should be rejected
   with a clear error rather than crashing the consumer

Commit as: "chore: ml-service skeleton + queue consumer + schema contract tests"
```

### Block B2 — Geo-routing (ward assignment)
```
Implement app/geo_cluster.py's ward-assignment half: point-in-polygon lookup
against ward boundaries (read from Postgres, same wards table Track A seeded in
Block A2 — coordinate directly with them on the exact table/column names, don't
guess).

Requirements:
- Given an issue's lat/lng, return ward_id + department (via dept-mapping table)
- Ambiguous/unassignable points (outside all wards, on a boundary) get flagged
  for human triage, not silently dropped or defaulted
- Publish the result back through the callback contract from Block A6

Testing before done:
1. Unit tests: point clearly inside a ward, point on a boundary, point outside
   all wards — each asserted against expected behavior
2. Integration test: consume a real RoutingJobPayload message, assert the
   correct callback payload is produced
3. Paste sample input/output pairs as Artifact

Commit as: "feat: geo-routing — ward + department assignment"
```

### Block B3 — Duplicate detection (image hash + embedding + geo-proximity)
```
Implement image_hash.py (perceptual hash), embedding.py (CLIP-style similarity,
can be a smaller/faster model given hackathon time budget — state which you
picked and why), and the dedup half of geo_cluster.py (ST_DWithin-style
geo-proximity query against Postgres).

Requirements:
- Combine geo-proximity (same category/area, recent open issues) + image
  similarity above a threshold → flag as duplicate_of_issue_id
- Threshold values must be configurable, not hardcoded magic numbers
- On confirmed duplicate: do not create a fresh ticket signal, increment the
  affected-citizens counter instead (per the callback contract)
- If no match: return "not a duplicate" explicitly, don't just return nothing

Testing before done:
1. Unit tests for pHash: near-duplicate photo pair scores high, unrelated
   photo pair scores low, using fixture images checked into a test-fixtures
   folder (small, checked-in, reproducible — no network fetch in tests)
2. Unit tests for the embedding similarity function, same pattern
3. Integration test: two issues submitted close together with similar photos
   → second gets duplicate_of_issue_id set
4. Integration test: two dissimilar issues → neither flagged

Commit as: "feat: duplicate detection — pHash + embedding + geo-proximity"
```

### Block B4 — Severity scoring + graceful degradation + sweep job
```
Implement severity.py: category weight × upvote count × affected-citizen count,
recalculated whenever any input changes (new upvote, dedup counter increments).

Requirements:
- Expose a recalculation entrypoint the consumer calls on the relevant events
- Sweep job: periodically scans for issues that never got routed/deduped
  (e.g. queue was down when they were created — see Track A Block A6's
  degradation note) and processes them retroactively
- Confirm the whole pipeline survives a queue outage: issue exists, gets
  processed late, ends up in the same final state as one processed live

Testing before done:
1. Unit test: severity formula correctness across a few input combinations
2. Integration test: simulate queue downtime during issue creation (coordinate
   with Track A's Block A6 test if possible, or replicate the same scenario
   independently), confirm sweep job catches it up correctly
3. Paste queue/log output showing the sweep job processing backlog as Artifact

Commit as: "feat: severity scoring + sweep job for degraded-queue recovery"
```

---

## 4. Track C — Android (owner: the Android person)

### `.agents/skills/android-conventions.md`
```
Stack: Kotlin, Jetpack (Room, WorkManager, Retrofit + Moshi/Gson), single-activity
+ Compose (state which navigation approach — Navigation-Compose recommended)
architecture, MVVM. Do not switch to Java, Flutter, or a different networking
stack without asking.
Contract: docs/api-spec.yaml is the source of truth for every network call —
generate Retrofit interfaces from it manually (keep them hand-written and
readable, this is a portfolio deliverable) rather than guessing endpoint shapes.
Auth header format must match exactly what Track A documents in Block A3.
Testing bar: JUnit + MockK for ViewModels/Repositories, instrumented tests for
Room DAOs, at least one Espresso/Compose UI test for the core submit flow.
```

### Block C1 — App skeleton + navigation + local DB
```
Read docs/api-spec.yaml and docs/architecture.md for context only — do not wire
real network calls yet.

Set up mobile/android per the given package structure:
- ui/ (Home, ReportIssue, MyReports, MapScreen, Profile — Compose screens,
  placeholder content for now)
- data/local (Room: IssueDao, IssueEntity, AppDatabase) matching the fields in
  the frozen Issue schema from docs/api-spec.yaml
- data/remote (ApiService interface stub generated from api-spec.yaml,
  RetrofitClient not yet pointed at a live server)
- data/repository (IssueRepository — reads/writes local DB only for now)
- sync/ (SyncWorker skeleton, no real sync logic yet)
- location/ (GeoLocationHelper), camera/ (CameraCaptureHelper) — permission
  handling wired, capture/fetch not yet connected to submission flow
- Navigation between all five screens

Testing before done:
1. App builds and installs on an emulator, all five screens navigable
2. Room DAO instrumented test: insert/read/update/delete an IssueEntity
3. Screenshot artifact of each screen (even as placeholders)
4. Lint (ktlint/detekt) clean

Commit as: "chore: android app skeleton, navigation, local Room DB"
```

### Block C2 — Auth (Firebase phone OTP) + secure token storage
```
Match Track A Block A3's Firebase project and header contract exactly — confirm
the exact auth header format with them before writing this, don't assume.

Requirements:
- Firebase Auth SDK, phone OTP login screen
- Store the ID token securely (EncryptedSharedPreferences or DataStore +
  Keystore-backed encryption), attach it to every authenticated Retrofit call
  via an OkHttp interceptor
- Token refresh handled transparently — a 401 triggers silent refresh + retry
  once before surfacing an error to the user
- Role (citizen/officer/admin) read from the ID token claims but NEVER trusted
  for anything beyond UI display — same principle as backend, enforcement is
  server-side only

Testing before done:
1. Unit test: interceptor attaches the token in the correct header format
2. Unit test: 401 triggers exactly one silent refresh+retry, not an infinite loop
3. Manual verification artifact: screenshot of successful OTP login against the
   same test Firebase project Track A is using
4. Confirm no Firebase service-account keys or client secrets are committed

Commit as: "feat: Firebase phone-OTP auth + secure token interceptor"
```

### Block C3 — Citizen submit flow (core loop, online path)
```
Wire ReportIssue screen to the real backend, matching Track A's Block A4
endpoint exactly (field names, idempotency key format, multipart photo upload).

Requirements:
- Capture photo (CameraCaptureHelper) or pick from gallery
- Auto-geotag via GeoLocationHelper, allow manual pin adjustment on a map
- Category dropdown + description field
- Generate a client UUID per submission (idempotency key — same mechanism as
  web), persist locally in Room BEFORE attempting network call
- Optimistic UI: show "submitted" state immediately, row's sync status updates
  to "confirmed" or "failed" based on server response
- Resubmitting the same local draft after a partial failure must reuse the same
  client UUID, never generate a new one

Testing before done:
1. Instrumented test: submitting with valid data creates a local Room row
   immediately, then updates to "confirmed" after a mocked successful response
2. Unit test: same client UUID reused across retry attempts of the same draft
3. UI test (Espresso/Compose test): full submit flow, photo through confirmation
   screen, against a mocked API service
4. Manual test against Track A's real running backend (not just mocks) —
   screenshot the created issue as it appears via GET /issues/:id

Commit as: "feat: citizen issue submission — camera, geotag, idempotent submit"
```

### Block C4 — Offline queue + WorkManager background sync
```
This is Android's version of Track A's Block A8 offline requirement — same
idempotency mechanism, different transport.

Requirements:
- All submissions always write to Room first regardless of connectivity
- SyncWorker (WorkManager, constrained to run only with network connectivity)
  drains unsynced rows, POSTs them using the same client UUID from Block C3
- Exponential backoff on failure, but never silently drops a submission
- MyReports screen reflects local + synced state accurately (pending / synced /
  failed, with a manual retry action for failed)

Testing before done:
1. Instrumented test: create rows while "offline" (mock connectivity check),
   confirm SyncWorker does not attempt network calls until connectivity mocked
   as available
2. Instrumented test: multiple pending rows all sync correctly, no duplicates
   server-side (verify against Track A's idempotency behavior — coordinate a
   joint test if time allows)
3. Manual test: airplane mode → submit 2-3 issues → reconnect → confirm all
   appear correctly in MyReports and on the officer console (cross-track check)

Commit as: "feat: offline-first submission queue with WorkManager background sync"
```

### Block C5 — MyReports, IssueDetail, status timeline, Profile
```
Requirements:
- MyReports: paginated list from GET /issues (filtered to current user),
  pull-to-refresh, merged with local pending/failed state from Room
- IssueDetail: full status timeline (StatusHistory) rendered as a vertical
  stepper, current status highlighted
- Profile: basic user info from the ID token + a logout flow that clears local
  session (not local issue drafts — those stay for resync/history)
- MapScreen: show the user's own issues as pins (Leaflet/OSM not needed here —
  use native Google Maps or Mapbox-free/OSM Android SDK, state which and why)

Testing before done:
1. Instrumented/UI test: MyReports reflects a mix of synced and pending items
   correctly
2. Instrumented test: IssueDetail renders a multi-step status timeline correctly
   from a mocked StatusHistory payload
3. Screenshot artifact: all four screens populated with real data from Track A's
   running backend

Commit as: "feat: MyReports, IssueDetail timeline, Profile, map pins"
```

---

## 5. Integration checkpoints (all three, together)

Don't wait until the end to find out the contract drifted. Put these on the clock:

- **Checkpoint 1 (after A2/A3, B1, C2):** confirm auth header format and DB schema match across all three tracks exactly. This is the single highest-risk drift point — verify it live, don't trust that Block 0's doc alone was enough.
- **Checkpoint 2 (after A6, B1):** Track A and Track B run a live end-to-end job through the real queue (not stubs) — issue created via A's API, routed and deduped by B's consumer, callback lands back in A's DB. Screenshot/log this as a joint Artifact.
- **Checkpoint 3 (after A4/A5, C3/C4):** Track C submits real issues against Track A's real running backend (not mocks) and Track A's officer console (Block A5 UI) shows them appearing and progressing through status changes triggered from Android.
- **Final integration block (all three):**
```
Run a full end-to-end smoke test across the live system:
1. Android app (Track C) submits an issue offline, syncs when reconnected
2. Backend (Track A) receives it, enqueues routing + dedup jobs
3. ML service (Track B) processes the jobs, ward/department/severity get set
4. Officer console (Track A's Stitch-integrated UI) shows it in queue, officer
   resolves it with an after-photo
5. Citizen sees the resolved status reflected back in the Android app and/or
   citizen-app web

Testing before done:
1. Record this entire flow as one browser-agent + manual screen-recording
   Artifact — this is your hackathon demo video draft, don't treat it as
   throwaway QA
2. Confirm no PII leaks in any public-facing response used by admin-console's
   public map (grep payloads)
3. Deploy: Railway for backend + web (per your original deploy notes), ML
   service as its own Railway service or a small always-on box if free-tier
   queue connectivity to Railway's Redis is a problem — flag this early, don't
   discover it at hour 40

Commit as: "chore: full-system integration + smoke test + deploy"
```

---

## 6. Token/efficiency notes (same discipline as your CivicTrack doc, applied to three parallel tracks)

- **One block per agent task, per person.** Three people running three simultaneous Antigravity tasks is fine and expected — that's the point of the split. Don't let any one person queue two blocks from their own track back-to-back without reviewing the first; that's how contract drift sneaks in.
- **Reference files by path.** `docs/api-spec.yaml`, `docs/architecture.md`, and the frozen event schemas already exist after Block 0 — every block above points at them instead of repasting. This matters even more across three tracks, since three people repasting the same context triples the waste.
- **Planning mode everywhere**, so each agent produces a task breakdown before touching code — this is what catches "the ML agent decided to add its own Postgres" or "the Android agent decided to use Volley instead of Retrofit" before it burns tokens.
- **Don't let tracks negotiate through their own agent threads.** If Track A and Track C disagree about a field name, that's a 2-minute human conversation, not something to argue about inside a coding agent's context window.
- **Kill and relaunch, don't argue**, same as before — if a block's run stalls or drifts, relaunch with a corrected prompt rather than negotiating with a derailed context.
- **Stitch stays separate from Antigravity.** Generate/iterate the UI designs in Stitch first, export once you're happy, *then* run Block A7 — don't loop Stitch exports through Antigravity repeatedly; that's redundant design-then-redesign token burn.
