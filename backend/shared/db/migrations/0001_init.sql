-- =============================================================================
-- Migration: 0001_init.sql
-- Description: Core schema — users, wards, departments, issues,
--              status_history, upvotes
-- PostGIS extension required (geography / geometry types).
-- NOTE: GIST and composite indexes are deferred to migration 0002 (Block A2),
--       but the column shapes frozen here ARE the shapes those indexes target.
-- =============================================================================

-- Ensure PostGIS is available (idempotent).
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- =============================================================================
-- ENUM types
-- =============================================================================

CREATE TYPE user_role AS ENUM (
    'CITIZEN',
    'OFFICER',
    'ADMIN'
);

CREATE TYPE issue_status AS ENUM (
    'REPORTED',
    'ACKNOWLEDGED',
    'IN_PROGRESS',
    'RESOLVED',
    'VERIFIED'
);

CREATE TYPE issue_category AS ENUM (
    'ROAD_DAMAGE',
    'WATERLOGGING',
    'GARBAGE',
    'STREETLIGHT',
    'SEWAGE',
    'ENCROACHMENT',
    'OTHER'
);

-- =============================================================================
-- TABLE: wards
-- Must be created before issues (foreign key target).
-- =============================================================================

CREATE TABLE wards (
    -- Primary key
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Human-readable ward name, e.g. "Ward 14 - Shivajinagar"
    name                TEXT            NOT NULL,

    -- GeoJSON/geometry polygon of the ward boundary.
    -- SRID 4326 = WGS-84.
    -- PostGIS GIST index added in migration 0002.
    boundary            geometry(Polygon, 4326)  NULL,

    -- Audit timestamps
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  wards             IS 'Municipal ward reference data.';
COMMENT ON COLUMN wards.boundary    IS 'WGS-84 polygon. GIST index deferred to 0002.';

-- =============================================================================
-- TABLE: departments
-- =============================================================================

CREATE TABLE departments (
    -- Primary key
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Department name, e.g. "Roads and Infrastructure"
    name                TEXT            NOT NULL,

    -- Audit timestamps
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE departments IS 'Municipal department reference data.';

-- =============================================================================
-- TABLE: users
-- =============================================================================

CREATE TABLE users (
    -- Primary key (internal UUID, separate from Firebase UID)
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Firebase UID from Firebase Auth — unique, never null.
    -- This is what the gateway resolves from the ID token.
    firebase_uid        TEXT            NOT NULL UNIQUE,

    -- Role granted server-side; never self-assignable via public API.
    role                user_role       NOT NULL DEFAULT 'CITIZEN',

    -- Display name from Firebase profile or manually set.
    display_name        TEXT            NOT NULL DEFAULT '',

    -- Phone number in E.164 format; populated for citizens (OTP auth).
    phone_number        TEXT            NULL,

    -- Email address; populated for officers/admins (email/Google auth).
    email               TEXT            NULL,

    -- For OFFICER role: the ward this officer is assigned to.
    ward_id             UUID            NULL REFERENCES wards(id) ON DELETE SET NULL,

    -- Audit timestamps
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  users             IS 'User accounts, synced from Firebase Auth.';
COMMENT ON COLUMN users.firebase_uid IS 'Raw Firebase UID string — unique index enforced.';
COMMENT ON COLUMN users.ward_id     IS 'Non-null only for OFFICER role.';

CREATE UNIQUE INDEX idx_users_firebase_uid ON users (firebase_uid);

-- =============================================================================
-- TABLE: issues
-- =============================================================================

CREATE TABLE issues (
    -- Primary key
    id                          UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Client-generated idempotency key (UUID v4).
    -- Stored to detect duplicate submissions from offline-first clients.
    -- (reporter_id, client_uuid) uniqueness enforced below.
    client_uuid                 UUID            NOT NULL,

    -- The citizen who reported this issue.
    reporter_id                 UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Issue category.
    category                    issue_category  NOT NULL,

    -- Free-text description provided by the citizen.
    description                 TEXT            NOT NULL,

    -- WGS-84 point geography (lat/lng) of the reported location.
    -- Uses geography(Point) for accurate distance calculations in metres.
    -- GIST index deferred to migration 0002.
    location                    geography(Point, 4326)  NOT NULL,

    -- Optional human-readable reverse-geocoded address from the client.
    address_hint                TEXT            NULL,

    -- Array of public photo URLs (stored as JSONB for simplicity at this scale).
    -- Each element is a string URL, e.g. "https://cdn.iota.app/issues/photo_abc.webp"
    photo_urls                  JSONB           NOT NULL DEFAULT '[]'::jsonb,

    -- Current status in the lifecycle state machine.
    status                      issue_status    NOT NULL DEFAULT 'REPORTED',

    -- Assigned ward (populated by routing-service after ML processing).
    ward_id                     UUID            NULL REFERENCES wards(id) ON DELETE SET NULL,

    -- Assigned department (populated by routing-service after ML processing).
    department_id               UUID            NULL REFERENCES departments(id) ON DELETE SET NULL,

    -- ML-computed severity score [0.0, 1.0]. Null until ml-service responds.
    severity_score              NUMERIC(4, 3)   NULL CHECK (severity_score BETWEEN 0 AND 1),

    -- If this issue is a duplicate, points to the canonical original issue.
    duplicate_of_issue_id       UUID            NULL REFERENCES issues(id) ON DELETE SET NULL,

    -- Perceptual hash of the first photo; stored for future dedup comparisons.
    image_phash                 TEXT            NULL,

    -- SLA deadline for resolution (computed by issue-service on creation).
    sla_due_at                  TIMESTAMPTZ     NULL,

    -- Audit timestamps
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  issues                        IS 'Civic issues reported by citizens.';
COMMENT ON COLUMN issues.client_uuid            IS 'Idempotency key generated by the client before the network call.';
COMMENT ON COLUMN issues.location               IS 'geography(Point,4326) — WGS-84. GIST index deferred to 0002.';
COMMENT ON COLUMN issues.photo_urls             IS 'JSONB array of public CDN URL strings.';
COMMENT ON COLUMN issues.severity_score         IS 'ML-assigned score [0,1]. NULL until ml-service publishes SeverityUpdatePayload.';
COMMENT ON COLUMN issues.duplicate_of_issue_id  IS 'Non-null when ML dedup flags this as a duplicate.';
COMMENT ON COLUMN issues.image_phash            IS 'pHash hex string from ml-service; used for future dedup lookups.';

-- Idempotency: one row per (reporter, client_uuid) pair.
CREATE UNIQUE INDEX idx_issues_reporter_client_uuid
    ON issues (reporter_id, client_uuid);

-- Fast lookup by ward + status (used heavily by officer queue).
-- Full composite GIST + B-tree indexes deferred to 0002.
CREATE INDEX idx_issues_ward_status
    ON issues (ward_id, status)
    WHERE ward_id IS NOT NULL;

-- SLA breach sweep job needs this.
CREATE INDEX idx_issues_sla_due_at
    ON issues (sla_due_at)
    WHERE sla_due_at IS NOT NULL AND status NOT IN ('RESOLVED', 'VERIFIED');

-- =============================================================================
-- TABLE: status_history
-- =============================================================================

CREATE TABLE status_history (
    -- Primary key
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- The issue this transition belongs to.
    issue_id        UUID            NOT NULL REFERENCES issues(id) ON DELETE CASCADE,

    -- Transition: from → to.
    from_status     issue_status    NOT NULL,
    to_status       issue_status    NOT NULL,

    -- The user (officer/admin/system) who performed the transition.
    actor_id        UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    -- Optional note explaining the transition.
    note            TEXT            NULL,

    -- Optional after-photo URL (required when to_status = 'RESOLVED').
    photo_url       TEXT            NULL,

    -- Timestamp of the transition.
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  status_history            IS 'Immutable audit log of every issue status transition.';
COMMENT ON COLUMN status_history.photo_url  IS 'Required (enforced in app layer) when to_status = RESOLVED.';

CREATE INDEX idx_status_history_issue_id
    ON status_history (issue_id, created_at);

-- =============================================================================
-- TABLE: upvotes
-- =============================================================================

CREATE TABLE upvotes (
    -- Composite primary key: one upvote per (user, issue) pair.
    issue_id        UUID            NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    user_id         UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (issue_id, user_id)
);

COMMENT ON TABLE upvotes IS 'Citizen corroboration upvotes. One per (issue, user) pair, enforced by PK.';

CREATE INDEX idx_upvotes_issue_id ON upvotes (issue_id);

-- =============================================================================
-- Automatic updated_at triggers
-- =============================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_wards_updated_at
    BEFORE UPDATE ON wards
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_departments_updated_at
    BEFORE UPDATE ON departments
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_issues_updated_at
    BEFORE UPDATE ON issues
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
