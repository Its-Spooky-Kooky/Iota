# IOTA — Digital Civic Issue Reporting Platform
### HackNova'26 | SDG 11: Sustainable Cities and Communities
### Team Submission Document

---

## 1. Problem Statement Explanation & Pain Points

### 1.1 The Problem, in One Line
Indian cities generate thousands of civic complaints every day — potholes, garbage overflow, water leakage, broken streetlights — but the reporting-to-resolution loop is **broken, opaque, and untrusted**. Citizens report issues into a void and rarely find out what happened next.

### 1.2 Why This Still Matters (Despite "1000 Apps Already Existing")
Government apps like Swachhata-MoHUA, city-specific tools like BBMP's FixMyStreet, and global tools like FixMyStreet (UK) and SeeClickFix (US) proved the *concept* works — citizens will report issues if given a camera and a button. But adoption plateaus and trust collapses because of **specific, repeatable failure patterns**, not because the idea is bad:

| # | Pain Point | Why It Happens Today |
|---|---|---|
| 1 | **Duplicate flooding** | 50 people report the same pothole as 50 separate tickets. Departments waste time triaging noise instead of fixing things. |
| 2 | **No visible accountability** | Complaint goes to a department queue and disappears. No SLA, no escalation, no proof it was even seen. |
| 3 | **Fake / unverifiable resolution** | Departments mark issues "resolved" without proof. Citizens have no way to contest a false closure. |
| 4 | **Spam & fake reports** | Anonymous reporting invites trolling, competitor sabotage (shopkeepers reporting rivals), and prank complaints — burning department trust and bandwidth. |
| 5 | **Wrong-department routing** | A water-logging complaint sent to the roads department sits untouched for weeks before someone manually forwards it. |
| 6 | **No prioritization signal** | A single missing manhole cover (dangerous) gets the same priority as a faded road-paint complaint (cosmetic). |
| 7 | **Connectivity blackout** | Field reporting from low-network areas (where infrastructure often *is* worst) fails — the exact areas that need this most are excluded. |
| 8 | **Fragmented experience** | Every city/state has a different app (Swachhata, BBMP FixMyStreet, various municipal portals) — no unified, learnable citizen experience. |
| 9 | **No community accountability layer** | There's no sense of "my neighborhood" — citizens don't see what's happening around them, so civic participation stays a one-off act instead of an ongoing habit. |

**IJERT's 2026 study on hybrid AI civic reporting systems** found that a Delhi pilot using AI classification and geospatial clustering achieved a 78% resolution rate against a historical baseline of 45%, and outperformed FixMyStreet (62%) and SeeClickFix (5.8-day average turnaround) — concrete proof that the *execution layer* (clustering, classification, transparency), not the base concept, is where the real differentiation and impact lives.

### 1.3 The Real Problem Statement (Reframed)
> It's not "citizens can't report issues." It's **"reports don't turn into trusted, trackable, prioritized action."** IOTA is a resolution-accountability platform that happens to start with a report button — not just another complaint box.

---

## 2. Proposed Solution — IOTA

### 2.1 Core Idea
IOTA treats every civic issue as a **verifiable, trackable case** — not a one-way complaint. The differentiators map 1:1 to the pain points above: verified identity kills spam, geo-image clustering kills duplicates, severity scoring kills mis-prioritization, auto-routing kills departmental misrouting, proof-of-resolution kills fake closures, and offline sync kills the connectivity gap.

### 2.2 Feature Breakdown

**a) Cross-platform apps (Web + Android)**
A citizen-facing Android app (Kotlin/Flutter) for on-the-ground reporting and a web app for citizens (case tracking, dashboards) *and* a separate web console for municipal staff/admins — three surfaces, one backend.

**b) Map Integration**
Live map (issue heatmap, cluster pins, department zone overlays) using an interactive maps SDK so citizens see what's already reported nearby before filing a new one — and municipal staff see workload distributed geographically.

**c) Issue Tracking System**
Every report becomes a case with a unique ID and a state machine: `Reported → Verified → Assigned → In Progress → Resolved (pending proof) → Closed / Reopened`. Citizens get push notifications on every transition.

**d) Profile Verification via Government ID**
Onboarding requires Aadhaar/DigiLocker-based (or equivalent govt ID) identity verification via OTP + document hash check — **not storing the raw ID**, only a verified boolean + hashed reference (see Security section). This single feature kills anonymous spam and troll reports, which is the #1 reason municipal staff don't trust citizen-reporting apps.

**e) Clustering of Duplicate Complaints (Image + Geo-location)**
When a new report comes in, a similarity pipeline (perceptual image hashing + CLIP-style embedding similarity + geofence radius, e.g. 25m) checks it against open cases in the same category. Matches get merged into one case as "supporting evidence," not a new ticket — this is the single highest-leverage engineering feature for standing out, since almost no existing app does automatic multi-modal duplicate clustering.

**f) Severity Classification (Upvotes + Report Count)**
A weighted score: `severity = f(unique_reporter_count, upvotes, category_risk_weight, time_open)`. Water leakage near a school escalates faster than a peeling wall poster. This score drives SLA timers and dashboard sort order for municipal staff — turning a flat queue into a prioritized worklist.

**g) Auto Community Assignment & Routing**
On signup, geo-location places the citizen into their ward/community group automatically (reverse-geocoding → ward boundary lookup). New reports are auto-routed to the correct department using a category→department mapping table keyed by ward, removing the manual forwarding step that currently costs days.

**h) Proof of Resolution**
Field staff must upload a geo-tagged, timestamped "after" photo (matched against the "before" photo's location) before a case can move to Resolved. The original reporter gets a push notification to confirm or reopen within a grace window (e.g. 72 hours) — closing the "fake resolved" trust gap directly.

**i) Offline-First Sync**
Reports created with no signal are queued in local storage (SQLite/Room on Android, IndexedDB on web) with photos compressed and cached locally, then synced automatically via a background job once connectivity returns — critical because the worst-infrastructure areas are often the worst-connectivity areas too.


---

## 3. Differentiation — IOTA vs Existing Apps

| Capability | Swachhata-MoHUA (Govt of India) | BBMP FixMyStreet (Bengaluru) | FixMyStreet (UK, open-source) | SeeClickFix / CivicPlus (US) | **IOTA** |
|---|---|---|---|---|---|
| Identity verification | Mobile OTP only | Mobile OTP only | None / optional email | Optional, email-based | **Govt-ID verified profile** |
| Duplicate handling | Manual upvote only | None reported | Manual "supporters" count | Manual, upvote-based | **Automatic image + geo clustering** |
| Prioritization | None (FIFO-ish) | None | None | Basic upvote count | **Weighted severity score (reports + upvotes + risk + time)** |
| Auto-routing to dept | Manual ward-based assignment by staff | Ward engineer manual pickup | Category-based, manual council routing | Category-based routing | **Auto ward + department routing on submit** |
| Proof of resolution | Photo upload by inspector, not geo-matched | Not standardized | Status update, no enforced photo-match | Photo optional | **Geo-matched before/after photo + citizen confirm-or-reopen** |
| Offline support | None documented | None documented | None documented | None documented | **Full offline queue + auto-sync** |
| Community grouping | None | None | Council-based (fixed) | City-based (fixed) | **Dynamic ward/community auto-assignment** |
| Platform | Android/iOS app | Android only | Web (+ mobile via browser) | Web + mobile | **Web + Android (cross-platform, offline-capable)** |

**Bottom line for judges:** every app on the left solves *reporting*. None of them solve *trust and prioritization* end-to-end. IOTA's four hard-engineering bets — duplicate clustering, severity scoring, verified identity, and enforced proof-of-resolution — are the parts that are genuinely difficult to build and genuinely missing from the field, which is exactly where hackathon judges look for technical depth.

---

## 4. System Architecture

### 4.1 Architectural Style
**Microservice-leaning modular monolith** for the hackathon timeline (fast to build, easy to demo, still cleanly separable into microservices later) with a clear boundary between:
1. Client layer (Android app, Web app, Admin console)
2. API Gateway / BFF (Backend-for-Frontend)
3. Core service layer (business logic, split into logical modules even inside one deployable)
4. Data layer (relational + geospatial + object storage + cache/queue)
5. Intelligence layer (ML: image similarity, duplicate clustering, severity scoring)

### 4.2 High-Level Architecture Diagram

```
                         ┌────────────────────────────────────────┐
                         │              CLIENT LAYER               │
                         │  ┌───────────┐ ┌───────────┐ ┌────────┐│
                         │  │ Android   │ │  Citizen  │ │ Admin  ││
                         │  │ App       │ │  Web App  │ │ Console││
                         │  │(Kotlin/   │ │ (React)   │ │(React) ││
                         │  │ Flutter)  │ │           │ │        ││
                         │  └─────┬─────┘ └─────┬─────┘ └───┬────┘│
                         │  Local SQLite/       (Direct HTTPS)     │
                         │  IndexedDB (offline queue)              │
                         └────────┼─────────────┼─────────────┼────┘
                                  │  HTTPS/REST + WebSocket (sync)  
                                  ▼             ▼             ▼
                         ┌────────────────────────────────────────┐
                         │        API GATEWAY / BFF (NGINX +       │
                         │        Node.js/NestJS or FastAPI)       │
                         │   - AuthN/AuthZ (JWT + govt-ID KYC)     │
                         │   - Rate limiting, request routing      │
                         └───────┬───────────────────┬────────────┘
                                 │                    │
             ┌───────────────────┼────────────────────┼────────────────────┐
             ▼                   ▼                    ▼                    ▼
    ┌────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
    │ Issue Service    │ │ Identity/KYC     │ │ Routing &         │ │ Notification      │
    │ - CRUD cases      │ │ Service          │ │ Community Service │ │ Service            │
    │ - State machine    │ │ - Govt ID hash   │ │ - Ward lookup     │ │ - Push (FCM)       │
    │ - Upvotes          │ │   + OTP verify   │ │ - Dept mapping    │ │ - SMS/email fallback│
    └────────┬────────┘ └──────────────────┘ └──────────┬────────┘ └──────────────────┘
             │                                            │
             ▼                                            ▼
    ┌────────────────────┐                     ┌──────────────────────┐
    │ ML / Intelligence    │◄────async queue────│  Message Queue        │
    │ Service (Python)     │                     │  (RabbitMQ / Kafka)   │
    │ - Perceptual image    │                     │  - image processing   │
    │   hashing + embedding │                     │  - notification jobs  │
    │ - Geo-duplicate match │                     │  - resolution proof   │
    │ - Severity scoring     │                     │    verification job   │
    └────────┬──────────────┘                     └──────────────────────┘
             │
             ▼
    ┌───────────────────────────────────────────────────────────────────┐
    │                              DATA LAYER                             │
    │  ┌───────────────┐ ┌───────────────────┐ ┌───────────────────────┐│
    │  │ PostgreSQL +   │ │ Object Storage      │ │ Redis (cache +        ││
    │  │ PostGIS        │ │ (S3 / Cloudinary)   │ │ session + rate-limit) ││
    │  │ (cases, users, │ │ - before/after       │ │                        ││
    │  │  wards, depts) │ │   photos, docs        │ │                        ││
    │  └───────────────┘ └───────────────────────┘ └───────────────────────┘│
    └───────────────────────────────────────────────────────────────────┘
```

### 4.3 Why This Architecture (Explained for Judges/Report)

- **API Gateway / BFF pattern**: A single entry point handles auth, rate-limiting, and routes to internal services. This means the mobile app, web app, and admin console can each get tailored responses without duplicating logic three times — and it's the natural seam to later split into real microservices without a rewrite.
- **Separate Identity/KYC service**: Government-ID verification has different security, compliance, and audit needs than everyday CRUD (issue reports). Isolating it means a breach or bug elsewhere in the system can't touch identity data, and it can be independently rate-limited and logged for compliance.
- **Async Message Queue between Issue Service and ML Service**: Image similarity search and severity scoring are CPU-heavier and shouldn't block the citizen's "submit" button. The citizen gets an instant "Report received" response; clustering/classification happens in the background within seconds and updates the case via WebSocket/push once done. This is what makes offline-sync and slow-network usage feel fast even though real ML is running underneath.
- **PostGIS over plain PostgreSQL**: Geo-radius queries ("find all open reports within 25m of this pin") are a core, constant operation (duplicate detection, ward assignment, map rendering). PostGIS gives spatial indexing (GiST) so these queries stay fast at scale instead of doing haversine math in application code.
- **Object storage separate from the database**: Photos/proof-of-resolution images are large binary blobs — keeping them in S3-compatible storage (not the DB) keeps the relational database fast and cheap, and lets you serve images via CDN.
- **Redis for cache + session**: Ward-boundary lookups and severity scores are read far more than written — caching these avoids repeated PostGIS/ML calls on every map refresh.
- **Offline-first client design**: The Android app and web app both maintain a local queue (SQLite/Room, IndexedDB) that mirrors the case-creation schema. A background sync worker (WorkManager on Android, Service Worker on web) replays queued reports once connectivity resumes, resolving conflicts by server-side idempotency keys generated client-side at creation time — so a report made offline never becomes a duplicate once synced.

### 4.4 Data Flow — "Report to Resolution" (Sequence)
1. Citizen submits report (photo + auto geo-tag) → stored locally if offline, else sent directly.
2. Gateway authenticates, Issue Service creates case with status `Reported`, publishes event to queue.
3. ML Service consumes event → checks image hash + geo-radius against open cases in category → if match found, merges as supporting evidence and bumps report_count; else creates a new cluster.
4. Severity score recalculated → if threshold crossed, status auto-escalates.
5. Routing Service resolves ward + department → case status becomes `Assigned`, department gets notified.
6. Field staff update status to `In Progress`, then `Resolved` — but `Resolved` requires a proof photo geo-matched to the original location.
7. Original reporter(s) get a push notification with the proof photo → confirm (`Closed`) or reject (`Reopened`, escalated with priority flag).

---

## 5. File / Project Structure (Monorepo)

A single monorepo keeps the Android app, web app, and backend services consistent and easy to demo/judge from one repository.

```
iota/
├── README.md
├── .env.example
├── docker-compose.yml                 # spins up postgres+postgis, redis, rabbitmq, minio (local S3), backend
├── docs/
│   ├── architecture.md
│   ├── api-spec.yaml                  # OpenAPI/Swagger spec
│   └── er-diagram.png
│
├── backend/
│   ├── gateway/                       # API Gateway / BFF
│   │   ├── src/
│   │   │   ├── middleware/ (auth.ts, rateLimit.ts)
│   │   │   ├── routes/
│   │   │   └── main.ts
│   │   └── package.json
│   │
│   ├── services/
│   │   ├── issue-service/
│   │   │   ├── src/
│   │   │   │   ├── controllers/
│   │   │   │   ├── models/ (case.model.ts, upvote.model.ts)
│   │   │   │   ├── state-machine/ (issue.states.ts)
│   │   │   │   └── main.ts
│   │   │   └── package.json
│   │   │
│   │   ├── identity-service/
│   │   │   ├── src/
│   │   │   │   ├── kyc/ (govtIdVerify.ts, otp.ts)
│   │   │   │   ├── models/ (user.model.ts)
│   │   │   │   └── main.ts
│   │   │   └── package.json
│   │   │
│   │   ├── routing-service/
│   │   │   ├── src/
│   │   │   │   ├── ward-lookup/
│   │   │   │   ├── dept-mapping/
│   │   │   │   └── main.ts
│   │   │   └── package.json
│   │   │
│   │   ├── notification-service/
│   │   │   ├── src/ (fcm.ts, sms.ts, email.ts, main.ts)
│   │   │   └── package.json
│   │   │
│   │   └── ml-service/                # Python
│   │       ├── app/
│   │       │   ├── image_hash.py      # perceptual hashing
│   │       │   ├── embedding.py       # CLIP-style similarity
│   │       │   ├── geo_cluster.py     # geo-radius duplicate check
│   │       │   ├── severity.py        # severity scoring model
│   │       │   ├── consumer.py        # queue consumer
│   │       │   └── main.py            # FastAPI app
│   │       ├── requirements.txt
│   │       └── models/                # ONNX / saved model weights
│   │
│   └── shared/
│       ├── db/ (migrations/, seed/)
│       └── libs/ (auth-lib, geo-lib, event-schemas)
│
├── web/
│   ├── citizen-app/                   # citizen-facing web app
│   │   ├── src/
│   │   │   ├── components/ (MapView, IssueCard, ReportForm, StatusTimeline)
│   │   │   ├── pages/ (Home, ReportIssue, MyReports, IssueDetail, Profile)
│   │   │   ├── hooks/ (useOfflineQueue.ts, useGeoLocation.ts)
│   │   │   ├── offline/ (indexedDbQueue.ts, syncWorker.ts)
│   │   │   ├── api/ (client.ts)
│   │   │   └── App.tsx
│   │   ├── public/
│   │   └── package.json
│   │
│   └── admin-console/                 # municipal staff dashboard
│       ├── src/
│       │   ├── components/ (WardHeatmap, PriorityQueue, ResolutionUpload)
│       │   ├── pages/ (Dashboard, CaseQueue, CaseDetail, Analytics)
│       │   └── App.tsx
│       └── package.json
│
├── mobile/
│   └── android/                       # Kotlin (or /flutter if using Flutter)
│       ├── app/
│       │   ├── src/main/java/com/iota/
│       │   │   ├── ui/ (screens: Home, ReportIssue, MyReports, MapScreen, Profile)
│       │   │   ├── data/
│       │   │   │   ├── local/ (Room: IssueDao.kt, IssueEntity.kt, AppDatabase.kt)
│       │   │   │   ├── remote/ (ApiService.kt, RetrofitClient.kt)
│       │   │   │   └── repository/ (IssueRepository.kt)
│       │   │   ├── sync/ (SyncWorker.kt — WorkManager background sync)
│       │   │   ├── location/ (GeoLocationHelper.kt)
│       │   │   ├── camera/ (CameraCaptureHelper.kt)
│       │   │   └── MainActivity.kt
│       │   └── build.gradle
│       └── settings.gradle
│
└── infra/
    ├── k8s/ (deployment manifests, per-service — for post-hackathon scaling)
    └── terraform/ (optional, cloud infra as code)
```

**Why monorepo for a hackathon:** one `docker-compose up` boots the entire stack for judges/demo, shared TypeScript types between gateway/services/web avoid drift, and your team can work on `mobile/`, `web/`, and `backend/services/*` in parallel without merge conflicts across repos.


---

## 6. Tech Stack — What & Why

### 6.1 Mobile (Android)
| Layer | Choice | Why |
|---|---|---|
| Language/Framework | **Kotlin (native)** or **Flutter** (pick one; Kotlin recommended if judges value "true native feel + easier Room/WorkManager offline sync"; Flutter if the team wants faster UI iteration and eventual iOS reuse) | Native Kotlin gives the tightest integration with Android's WorkManager (background sync) and CameraX (geo-tagged capture), both central to two of your headline features. |
| Local DB | **Room (SQLite)** | Offline-first requirement needs a real local relational store with query support, not just key-value — Room gives type-safe DAOs and easy migration to sync logic. |
| Background sync | **WorkManager** | Guarantees queued reports sync even if the app is closed/killed, respecting battery/network constraints automatically. |
| Maps | **Google Maps SDK (or Mapbox if avoiding Google billing)** | Mature clustering support (marker clustering) out of the box — directly supports your duplicate-visualization feature. |
| Networking | **Retrofit + OkHttp** | Industry-standard, handles interceptors for JWT auth and retry logic cleanly. |
| Image capture/compress | **CameraX + EXIF geo-tagging** | Ensures every photo is geo-tagged at capture, not relying on gallery metadata which can be stripped. |

### 6.2 Web
| Layer | Choice | Why |
|---|---|---|
| Frontend framework | **React + TypeScript** | Component reuse between citizen app and admin console; TS catches schema drift against backend contracts. |
| State/data fetching | **React Query (TanStack Query)** | Built-in caching + background refetch matches your "live status updates" requirement without hand-rolled polling logic. |
| Offline storage | **IndexedDB (via Dexie.js)** | Browser-native structured storage for the offline queue, mirroring the mobile Room schema. |
| Maps | **Mapbox GL JS / Leaflet** | Leaflet is free and open-source (good for a hackathon budget), supports clustering plugins natively. |
| Styling | **Tailwind CSS** | Fast to build a clean, consistent UI across citizen app and admin console under time pressure. |

### 6.3 Backend
| Layer | Choice | Why |
|---|---|---|
| API Gateway/BFF | **Node.js + NestJS** | Opinionated, modular structure maps directly onto your service boundaries (issue, identity, routing, notification) — and NestJS's built-in guards make JWT auth + role-based access (citizen vs staff) straightforward. |
| ML Service | **Python + FastAPI** | Python has the ecosystem (OpenCV, imagehash, sentence-transformers/CLIP) for image similarity and clustering — no other language gets you there as fast in a hackathon window. |
| Database | **PostgreSQL + PostGIS extension** | You need real geospatial querying (radius search, ward polygon containment) — PostGIS is the industry-standard extension for exactly this, and it's free/open-source. |
| Cache/session | **Redis** | Fast key-value store for session tokens, rate-limiting counters, and caching ward-lookup results. |
| Message queue | **RabbitMQ (or Redis Streams if you want to avoid a 2nd infra piece)** | Decouples the "instant response to citizen" from "heavier ML processing," which is core to your architecture's responsiveness. |
| Object storage | **AWS S3 / Cloudinary / MinIO (self-hosted, for local dev)** | Cloudinary specifically gives free-tier image transformation (compression, thumbnails) which helps mobile bandwidth on slow networks. |
| Auth | **JWT + OTP-based govt ID verification (DigiLocker API / Aadhaar e-KYC sandbox)** | DigiLocker's API is built for exactly this — verifying a citizen's identity against a government-issued document without your team ever storing the raw Aadhaar number. |

### 6.4 ML / Intelligence Layer
| Component | Choice | Why |
|---|---|---|
| Duplicate image matching | **Perceptual hashing (pHash/imagehash)** + **CLIP embeddings (via `sentence-transformers` or ONNX-exported model)** | pHash is a fast first-pass filter (near-instant, no GPU needed); CLIP embeddings catch semantic duplicates (same pothole from a different angle) that pHash alone would miss. Two-stage pipeline balances speed and accuracy. |
| Geo-duplicate check | **PostGIS `ST_DWithin` radius query** | Combined with the image similarity score to confirm duplicates — geo-proximity alone isn't enough (two different issues can be 5m apart), and image similarity alone isn't enough (same pothole photographed differently) — needing both is what makes this genuinely hard to fake. |
| Severity scoring | **Weighted rule-based model to start** (`reports × w1 + upvotes × w2 + category_risk × w3 − decay(time)`), upgradeable to a trained regression model post-hackathon once you have labeled resolution-time data | A rule-based model is explainable to judges and municipal staff (important for trust/adoption) and can be built and tuned within a hackathon timeframe; ML-heavy scoring is a good "future work" slide. |
| Deployment format | **ONNX** for any trained model components | Portable, fast inference, and keeps the ML service lightweight — this also lines up with standard mobile-adjacent ML deployment practice. |


---

## 7. Security & Privacy — Critical Considerations

Because IOTA handles **government ID data + real-time location + photos of public/private property**, security isn't optional polish — it's a judged criterion and a real-world legal requirement (India's DPDP Act, 2023).

### 7.1 Identity & Government ID Data
- **Never store raw Aadhaar/government ID numbers.** Use DigiLocker's consent-based verification flow or a KYC provider's tokenized response — store only a `verified: true/false` flag and a non-reversible hash/reference token, never the document image or number itself.
- **Consent-first flow**: explicit opt-in screen before ID verification, explaining exactly what's checked and what's stored (transparency builds the trust your differentiation depends on).
- **Data minimization**: only request the fields you actually need (name + verified status), not full KYC document data.

### 7.2 Location Data
- Geo-tag photos only at the moment of capture for a report — do **not** continuously track user location in the background.
- Store precise coordinates only against the *report*, not against the *user's ongoing movement*. A user's home location should never be inferable from your access logs.
- Round/fuzz displayed location precision on public map views (e.g., show issue clusters, not exact citizen home addresses) so complainants aren't personally identifiable to the public from the map alone.

### 7.3 Photo Data
- Strip EXIF metadata **except geo-tag** before public display (device model/serial can fingerprint a user).
- Run uploaded images through a moderation check (NSFW/violence classifier) before they're publicly visible — citizen-uploaded photo pipelines are a common abuse vector.
- Proof-of-resolution photos should be watermarked with timestamp + case ID server-side to prevent staff from reusing old photos to fake a "resolved" status.

### 7.4 Authentication & Authorization
- **JWT with short-lived access tokens + refresh token rotation.**
- **Role-based access control (RBAC)**: citizen, verified citizen, department staff, ward admin, super admin — each with a strictly scoped permission set (e.g., staff can only update cases routed to their department/ward).
- Rate-limit report submission per verified user (prevents spam floods even from verified accounts) and per IP (prevents unauthenticated abuse on public endpoints).

### 7.5 Anti-Abuse / Integrity
- Duplicate-clustering logic doubles as an anti-spam layer, but add a separate **report-velocity anomaly check** (e.g., same user reporting 20 issues in 2 minutes) to flag likely bot/troll activity for manual review.
- Proof-of-resolution photos must be geo-matched (within a tolerance radius) to the original report's coordinates — prevents staff from uploading an unrelated "fixed" photo to close a case fraudulently.
- Audit log every state transition (who changed what, when) — this is both a security control and your "transparent resolution updates" feature from the problem statement.

### 7.6 Infrastructure
- All traffic over HTTPS/TLS; encrypt sensitive fields (identity tokens, PII) at rest in Postgres (`pgcrypto` or column-level encryption).
- Secrets (API keys, DB credentials) via environment variables / a secrets manager — never hardcoded, never committed to the repo (add `.env` to `.gitignore` from commit #1).
- Regular dependency scanning (`npm audit`, `pip-audit`) — cheap to set up, and judges do notice a security-conscious `README`/CI setup.

### 7.7 Compliance Note (mention this in your report — it signals maturity)
Design decisions above are aligned with India's **Digital Personal Data Protection Act, 2023 (DPDP Act)** principles: purpose limitation (only collect what's needed for civic reporting), storage limitation, and consent-based processing of personal/identity data. You don't need to be a legal expert to state this — a short paragraph shows judges you thought about it.


---

## 8. Pitching Guide

### 8.1 Structure (aim for 5–7 minutes + Q&A)
1. **Hook (30s)** — Open with a real, specific, visualizable pain point, not a statistic. E.g.: *"Every one of you has photographed a pothole and sent it to a WhatsApp group that went nowhere. That's the entire civic complaint system in most of India today."*
2. **Problem (45s)** — 3 pain points max, the sharpest ones: duplicate flooding, no accountability, fake resolutions. Don't read your whole pain-point table — judges have it in the doc.
3. **"Why not just use Swachhata/FixMyStreet?" (60s)** — Address this head-on before they ask it. Show the differentiation table for 10 seconds, then say the one sentence that matters: *"Those apps solve reporting. We solve trust — verified identity, automatic duplicate merging, and enforced proof of resolution."*
4. **Live demo (2–2.5 min)** — This is the section that wins or loses the room. Script it tightly:
   - Citizen reports a pothole (show geo-tag + camera capture).
   - Show a *second* simulated report of the same pothole auto-merging instead of creating a duplicate ticket (this is your best "wow" moment — rehearse it until it's reliable).
   - Switch to admin console: show the case appearing pre-routed to the right department with a severity score.
   - Mark resolved with a proof photo → citizen gets notified → confirms.
   - If Android + web both demo cleanly, show the same case syncing across both.
5. **Architecture (30–45s)** — One slide, the diagram from Section 4, spoken as: *"citizen apps write offline-first, an async ML pipeline handles duplicate detection and severity without blocking the user, PostGIS gives us real geospatial matching."* Don't over-explain; the diagram should carry it visually.
6. **Impact/SDG framing (30s)** — Tie back explicitly to SDG 11 (sustainable cities): faster resolution → safer streets/public health outcomes, transparent tracking → institutional trust and accountability, offline support → equitable access for underserved/low-connectivity areas (this is often the most under-used point — infrastructure gaps and connectivity gaps overlap, and your offline sync directly targets that equity angle).
7. **Close (15s)** — One line on what's next post-hackathon (e.g., pilot with a ward office, add a trained severity model). Ends the pitch on momentum, not "thank you."

### 8.2 Delivery Tips
- **Lead with the demo, not the slides**, if your time is tight — a working duplicate-merge demo beats any architecture diagram for judge attention.
- Assign **one team member per system** (mobile, web/admin, backend/ML) to answer follow-up questions in their depth area — judges often probe technical depth in Q&A, and a single spokesperson who can't answer backend questions confidently costs more points than it saves.
- Have a **fallback**: pre-recorded screen capture of the demo in case of live wifi/demo failure — a silent pause killing your 2-minute demo window is the single most common hackathon pitch failure.
- Know your **numbers** cold: your target resolution-rate improvement (cite the IJERT Delhi pilot's 78% vs 45% baseline as an evidence anchor, not a claim about your own untested system — be precise that this is *comparable research*, not your measured result).

### 8.3 Anticipated Judge Questions (prepare answers)
- *"How do you verify the resolution photo isn't fake/reused?"* → Geo-match tolerance + timestamp watermark + citizen confirm-or-reopen window (Section 7.5).
- *"What stops a department from just ignoring the auto-routed case?"* → SLA timer tied to severity score with auto-escalation to ward admin if untouched past threshold (mention as a near-term feature if not built yet — be honest about what's built vs planned).
- *"Why government ID and not just phone OTP?"* → Phone OTP is what every existing app already does and doesn't stop spam/troll accounts (SIM cards are cheap); ID verification is what removes anonymous abuse, which is your core differentiator.
- *"How does this scale to a whole city/state?"* → Point to the microservice-ready architecture (Section 4) — each service can be independently scaled/deployed; PostGIS indexing keeps geo-queries fast at scale.


---

## 9. Implementation Plan

Assume a typical hackathon window (~24–36 hours build time). Adjust hours to your actual schedule, but keep the *order* — it's designed so you always have a demoable product even if you run out of time.

### Phase 0 — Setup (first 1–2 hours)
- Repo scaffold (monorepo structure from Section 5), `docker-compose.yml` for local Postgres+PostGIS, Redis, RabbitMQ.
- Agree on API contract early (OpenAPI spec stub) so mobile/web/backend teams can work in parallel against a mock before real endpoints exist.
- Split into 3 tracks: **Mobile**, **Web (citizen + admin)**, **Backend + ML**.

### Phase 1 — Core Vertical Slice (hours 2–10) — *build the thinnest working end-to-end path first*
- Backend: Issue Service CRUD + basic auth (skip full govt-ID KYC for now, stub as "verified: true").
- Mobile: report form (photo + geo-tag) → hits real API, no offline queue yet.
- Web citizen app: list + detail view of reports, live status.
- Web admin console: raw case list, manual status update.
- **Milestone check**: you can report an issue on the phone and see/update it on the admin web console. This is your safety-net demo if nothing else works later.

### Phase 2 — Differentiator Features (hours 10–20) — *this is where you win the hackathon*
- ML Service: perceptual hashing + geo-radius duplicate check (start rule-based/simple, refine if time allows). Wire via message queue.
- Severity scoring (rule-based formula from Section 6.4).
- Auto-routing: ward lookup + department mapping table.
- Proof-of-resolution flow: staff upload → geo-match check → citizen confirm/reopen.
- Offline queue: Room (mobile) / IndexedDB (web) + background sync worker.
- **Milestone check**: two duplicate reports auto-merge; a resolved case requires a matched proof photo.

### Phase 3 — Identity & Security Hardening (hours 20–26)
- Real (or sandbox) DigiLocker/govt-ID verification flow.
- JWT auth hardening, RBAC for staff vs citizen roles.
- Rate limiting on report submission.
- Strip EXIF except geo-tag on public display; basic image moderation stub if time allows.

### Phase 4 — Polish, Demo Prep & Docs (final hours)
- UI pass on both apps (consistent styling, Tailwind theme).
- Seed demo data (a realistic set of pre-existing reports so the map/admin dashboard doesn't look empty).
- Rehearse the demo script from Section 8 at least twice, live.
- Record the fallback video.
- Finalize this document + architecture diagram export for submission.

### Team Allocation Suggestion (adjust to your actual team size/skills)
| Role | Responsibility |
|---|---|
| Backend/API lead | Gateway, Issue Service, Identity Service, DB schema |
| ML/Data lead | Duplicate clustering, severity scoring, queue consumer |
| Mobile lead | Android app, offline sync, camera/geo capture |
| Web lead | Citizen web app + admin console |
| Design/Pitch lead | UI consistency, demo script, slide deck, pitch delivery |

*(If your team is smaller than 5, merge Backend/ML and Web/Design — but keep Mobile as its own owner, since it has the most platform-specific gotchas.)*


---

## 10. Vibe-Coding Complete Guide (Using AI Coding Tools for This Project)

"Vibe-coding" this project well means using AI (Claude Code, Cursor, Copilot, etc.) as a fast execution partner while *you* stay the architect — the biggest risk in a hackathon is AI generating plausible-looking code across services that don't actually integrate. Here's how to avoid that.

### 10.1 Set Up the Guardrails First (before writing any feature code)
1. **Write the API contract before generating any code.** Create `docs/api-spec.yaml` (OpenAPI) by hand or with AI help, listing every endpoint, request/response shape, and error codes for all services. This single file is what stops the mobile AI-generated client and backend AI-generated server from drifting apart — always paste the relevant spec section into your prompt when generating client or server code for an endpoint.
2. **Write the DB schema early** (`shared/db/migrations`) and treat it as a source of truth — generate all model code (TypeScript interfaces, Kotlin data classes, Python Pydantic models) *from* this schema rather than letting AI invent field names independently in each service.
3. **One shared "events" schema** for anything going through the message queue (e.g., `IssueCreatedEvent`, `DuplicateMergedEvent`) — put it in `backend/shared/libs/event-schemas` and reference it explicitly whenever prompting AI to write a queue producer or consumer.

### 10.2 Prompting Patterns That Work Well for This Project
- **Give the AI the file tree section relevant to the task**, not the whole repo — e.g., when building the ML duplicate-clustering endpoint, paste just the `ml-service/app/` structure and the relevant part of the API spec, plus the event schema it needs to consume/publish.
- **Ask for one module at a time with explicit inputs/outputs**, e.g.: *"Write `geo_cluster.py`: given a new report's (lat, lng, category) and a list of open cases in that category with their coordinates, return the closest match within 25 meters using PostGIS `ST_DWithin`, or null. Assume this function is called from `consumer.py` after `image_hash.py` has already confirmed image similarity above 0.85."* — specificity like this prevents AI from inventing its own architecture that doesn't match Section 4.
- **For the offline-sync logic (mobile + web)**, explicitly describe the conflict-resolution rule every time you prompt: *"Each locally queued report has a client-generated UUID as idempotency key; on sync, POST with this key; server upserts, never creates a duplicate if the key already exists."* This is the part most likely to get silently wrong if you under-specify it.
- **When debugging integration issues** (e.g., mobile app can't reach backend), give the AI the actual error/log output plus the exact request being made — vague prompts like "it's not working" produce vague, often wrong fixes and burn your limited hackathon time.

### 10.3 Division of Labor Between You and the AI
| You should always do | AI should mostly do |
|---|---|
| Decide the architecture (Section 4) and API contract | Generate boilerplate CRUD, DTOs, form validation |
| Decide security-sensitive logic yourself (identity verification flow, what gets stored/hashed) | Write standard integration code (Retrofit clients, React Query hooks) |
| Review any AI-generated code that touches auth, PII, or the govt-ID flow line by line | Generate test data / seed scripts |
| Own the demo script and rehearse it yourself | Draft README, docstrings, and inline comments |
| Make the final call on trade-offs when time runs short (which feature to cut) | Suggest options quickly so you can decide faster |

### 10.4 Speed Tactics for a Hackathon Timeline
- **Scaffold all services' boilerplate (NestJS modules, FastAPI app skeleton, Room DB setup, React project) in the first hour** using AI — this is low-risk, high-time-savings work.
- **Mock the ML service's response early** (return a hardcoded "not a duplicate, severity=3" response) so mobile/web/admin teams can build and demo against a stable contract while the real clustering logic is developed in parallel — swap the mock for the real implementation later without touching client code.
- **Use AI to generate seed/demo data** (a realistic batch of 30–50 fake reports across your ward map) — this is exactly the kind of tedious-but-necessary task AI is fastest at, and it's what makes your demo look like a real, populated city dashboard instead of an empty database.
- **Don't let AI choose your tech stack mid-build.** Lock in Section 6 as a team decision before generating code — switching frameworks 10 hours in because an AI suggested something "better" is the most common way hackathon teams run out of time.
- **Keep a running `PROGRESS.md`** where each team member logs what they finished / what's blocked — feed this into your AI tool's context when asking it to help debug cross-team integration issues, since it usually needs to know what actually exists versus what's still a stub.

### 10.5 Common Vibe-Coding Traps to Avoid in This Specific Project
- AI generating **duplicate detection logic that only checks geo-distance OR image similarity, not both** — re-read your own spec (Section 4.4) before accepting generated clustering code; both signals are the point.
- AI storing the **raw government ID or Aadhaar number** because a prompt like "add government ID verification" doesn't specify the privacy constraint — always explicitly state "store only a verified boolean and a hashed reference, never the raw ID" in any prompt touching identity.
- AI implementing **offline sync as simple retry-on-reconnect without idempotency keys** — this silently creates duplicate reports on flaky networks, exactly the bug that would embarrass you in a live demo on hackathon wifi.
- Accepting AI's default **map marker rendering without clustering** at the frontend level (visually messy with many pins) — explicitly ask for marker-clustering libraries (Leaflet.markercluster / Google Maps MarkerClusterer), don't assume it's included by default.

