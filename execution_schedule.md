# IOTA Parallel Execution Schedule

Because all three tracks (Backend/Web, ML, Android) work in parallel, managing the merge points and integration checkpoints is critical. The playbook dictates a "Contract-First" approach to prevent the tracks from blocking each other.

Here is the exact, chronologically ordered sequence of blocks to process for a perfect, conflict-free creation, structured around the mandatory integration checkpoints.

---

## Phase 0: The Frozen Contract (Completed)
Before anyone starts coding, the API and Queue contracts must be frozen. 
- **All Tracks:** Block 0 (API Spec, DB Migrations, Event Schemas).
  *(Note: Based on the repo tree, this has already been completed!)*

---

## Phase 1: Infrastructure, Skeleton, & Auth
All tracks start by standing up their basic skeletons and authentication layers based on the frozen contracts.

- **Track A:** 
  - `Block A1` — Monorepo skeleton + infra (Docker compose)
  - `Block A2` — Database schema + PostGIS + seed data
  - `Block A3` — Auth (Firebase) + RBAC
- **Track B:** 
  - `Block B1` — Service skeleton + queue consumer plumbing
- **Track C:** 
  - `Block C1` — App skeleton + navigation + local DB
  - `Block C2` — Auth (Firebase) + secure token storage

> [!IMPORTANT]
> **Integration Checkpoint 1 (After A3, B1, C2)**
> **STOP AND VERIFY:** Confirm the auth header format matches exactly between Track A (Backend) and Track C (Android). Ensure Track B's consumer is pointing to the correct queue infrastructure set up by Track A in Block A1.

---

## Phase 2: Core Workflows & Async Plumbing
Now tracks diverge to build their core functional logic.

- **Track A:** 
  - `Block A4` — Citizen submit flow (core loop)
  - `Block A5` — Officer console (triage + status lifecycle)
  - `Block A6` — Queue integration point (producer + callback contract)
- **Track B:** 
  - `Block B2` — Geo-routing (ward assignment)
  - `Block B3` — Duplicate detection (hash + embedding + geo-proximity)
  - `Block B4` — Severity scoring + sweep job
- **Track C:** 
  - `Block C3` — Citizen submit flow (core loop, online)
  - `Block C4` — Offline queue + WorkManager background sync

> [!IMPORTANT]
> **Integration Checkpoint 2 (After A6 and Track B completes)**
> **STOP AND VERIFY:** Test the queue boundary. Track A and Track B run a live end-to-end job through the real queue. Create an issue via Track A's API, verify Track B routes and dedups it, and the callback lands back in Track A's DB.

> [!IMPORTANT]
> **Integration Checkpoint 3 (After A5 and C4)**
> **STOP AND VERIFY:** Test the client boundary. Track C (Android) submits real issues against Track A's real running backend. Verify that Track A's officer console (from Block A5) shows the issues appearing and progressing through status changes.

---

## Phase 3: Polish & UI
With the core backend and ML logic verified, apply the final frontend polish.

- **Track A:** 
  - `Block A7` — Stitch UI integration (citizen-app + admin-console)
  - `Block A8` — Rate limiting, offline queue, CI/CD
- **Track C:** 
  - `Block C5` — MyReports, IssueDetail, status timeline, Profile, Maps

---

## Phase 4: Final Smoke Test & Deploy
- **All Tracks:** `Final integration block`
  - Run a full end-to-end smoke test across the live system: Android offline submit → Sync → Backend queue → ML Service routing/dedup → Officer console resolution. 
  - Deploy to Railway.
