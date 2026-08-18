/**
 * IOTA — Queue Event Schemas (TypeScript source of truth)
 *
 * These types define the exact shape of every message that crosses the
 * queue boundary between backend/gateway ↔ ml-service.
 *
 * FIELD NAMING RULE: all fields are snake_case.
 * The Python mirror in services/ml-service/app/schemas.py MUST use
 * identical field names — any mismatch silently breaks the queue contract.
 *
 * Nullability: fields typed `X | null` are present in every payload but
 * may carry a null value.  Optional fields (`field?: X`) may be entirely
 * absent from the serialised JSON.
 *
 * @generated-contract  Do not edit field names without updating schemas.py.
 */

// ─────────────────────────────────────────────────────────────────
// Shared / primitive types
// ─────────────────────────────────────────────────────────────────

/** ISO-8601 datetime string, e.g. "2026-02-15T10:00:00Z" */
export type ISODateTime = string;

/** UUID v4 string, e.g. "c3d4e5f6-a7b8-9012-cdef-345678901234" */
export type UUIDString = string;

export type IssueCategory =
  | "ROAD_DAMAGE"
  | "WATERLOGGING"
  | "GARBAGE"
  | "STREETLIGHT"
  | "SEWAGE"
  | "ENCROACHMENT"
  | "OTHER";

// ─────────────────────────────────────────────────────────────────
// Inbound: backend → ml-service
// ─────────────────────────────────────────────────────────────────

/**
 * Enqueued by issue-service immediately after a new issue row is created.
 * ml-service uses this to determine ward/department assignment.
 *
 * Queue name: "routing_jobs"
 */
export interface RoutingJobPayload {
  /** Discriminator — always "routing_job" */
  job_type: "routing_job";

  /** The issue to route. */
  issue_id: UUIDString;

  /** Category drives department-mapping fallback logic. */
  category: IssueCategory;

  /** WGS-84 latitude of the reported location. */
  latitude: number;

  /** WGS-84 longitude of the reported location. */
  longitude: number;

  /** ISO-8601 timestamp when this job was enqueued. */
  enqueued_at: ISODateTime;
}

/**
 * Enqueued by issue-service alongside RoutingJobPayload.
 * ml-service uses perceptual hashing, embedding similarity, and geo
 * proximity to detect duplicate issues.
 *
 * Queue name: "dedup_jobs"
 */
export interface DedupJobPayload {
  /** Discriminator — always "dedup_job" */
  job_type: "dedup_job";

  /** The candidate issue being checked for duplication. */
  issue_id: UUIDString;

  /** Category — used to narrow the dedup search space. */
  category: IssueCategory;

  /** WGS-84 latitude of the reported location. */
  latitude: number;

  /** WGS-84 longitude of the reported location. */
  longitude: number;

  /**
   * Public URLs of the issue's photos.
   * May be empty if no photos were attached.
   */
  photo_urls: string[];

  /**
   * Client-generated description text; used for text-embedding similarity.
   */
  description: string;

  /** ISO-8601 timestamp when this job was enqueued. */
  enqueued_at: ISODateTime;
}

// ─────────────────────────────────────────────────────────────────
// Outbound: ml-service → backend (routing-service / issue-service)
// ─────────────────────────────────────────────────────────────────

/**
 * Published by ml-service after processing both RoutingJobPayload and
 * DedupJobPayload for an issue.  routing-service consumes this and
 * applies the update to the issue row via issue-service.
 *
 * Queue name: "ml_results"
 */
export interface SeverityUpdatePayload {
  /** Discriminator — always "severity_update" */
  job_type: "severity_update";

  /** The issue this result applies to. */
  issue_id: UUIDString;

  /**
   * Severity score in the range [0.0, 1.0].
   * Higher = more severe.  null if scoring model failed (non-fatal).
   */
  severity_score: number | null;

  /**
   * Ward UUID determined by geo lookup against the wards table.
   * null if lookup failed (routing-service will retry via sweep job).
   */
  ward_id: UUIDString | null;

  /**
   * Department UUID determined by category → department mapping.
   * null if lookup failed.
   */
  department_id: UUIDString | null;

  /**
   * If this issue is a duplicate, the UUID of the canonical (original)
   * issue.  null means not a duplicate.
   */
  duplicate_of_issue_id: UUIDString | null;

  /**
   * Perceptual hash of the first attached photo (pHash, hex string).
   * Stored by backend for future dedup comparisons.
   * null if no photos were attached.
   */
  image_phash: string | null;

  /**
   * Confidence score for the duplicate decision, range [0.0, 1.0].
   * null when duplicate_of_issue_id is null.
   */
  dedup_confidence: number | null;

  /** ISO-8601 timestamp when ml-service published this result. */
  processed_at: ISODateTime;
}

// ─────────────────────────────────────────────────────────────────
// JSON Schema representations (for runtime validation / docs)
// ─────────────────────────────────────────────────────────────────

export const ROUTING_JOB_SCHEMA = {
  $schema: "https://json-schema.org/draft/2020-12/schema",
  $id: "RoutingJobPayload",
  type: "object",
  required: ["job_type", "issue_id", "category", "latitude", "longitude", "enqueued_at"],
  additionalProperties: false,
  properties: {
    job_type: { type: "string", const: "routing_job" },
    issue_id: { type: "string", format: "uuid", example: "c3d4e5f6-a7b8-9012-cdef-345678901234" },
    category: {
      type: "string",
      enum: ["ROAD_DAMAGE", "WATERLOGGING", "GARBAGE", "STREETLIGHT", "SEWAGE", "ENCROACHMENT", "OTHER"],
      example: "ROAD_DAMAGE",
    },
    latitude: { type: "number", minimum: -90, maximum: 90, example: 18.5204 },
    longitude: { type: "number", minimum: -180, maximum: 180, example: 73.8567 },
    enqueued_at: { type: "string", format: "date-time", example: "2026-02-15T10:00:00Z" },
  },
} as const;

export const DEDUP_JOB_SCHEMA = {
  $schema: "https://json-schema.org/draft/2020-12/schema",
  $id: "DedupJobPayload",
  type: "object",
  required: ["job_type", "issue_id", "category", "latitude", "longitude", "photo_urls", "description", "enqueued_at"],
  additionalProperties: false,
  properties: {
    job_type: { type: "string", const: "dedup_job" },
    issue_id: { type: "string", format: "uuid", example: "c3d4e5f6-a7b8-9012-cdef-345678901234" },
    category: {
      type: "string",
      enum: ["ROAD_DAMAGE", "WATERLOGGING", "GARBAGE", "STREETLIGHT", "SEWAGE", "ENCROACHMENT", "OTHER"],
      example: "ROAD_DAMAGE",
    },
    latitude: { type: "number", minimum: -90, maximum: 90, example: 18.5204 },
    longitude: { type: "number", minimum: -180, maximum: 180, example: 73.8567 },
    photo_urls: {
      type: "array",
      items: { type: "string", format: "uri" },
      example: ["https://cdn.iota.app/issues/photo_abc123.webp"],
    },
    description: { type: "string", minLength: 0, maxLength: 1000, example: "Large pothole near Shivaji Market." },
    enqueued_at: { type: "string", format: "date-time", example: "2026-02-15T10:00:00Z" },
  },
} as const;

export const SEVERITY_UPDATE_SCHEMA = {
  $schema: "https://json-schema.org/draft/2020-12/schema",
  $id: "SeverityUpdatePayload",
  type: "object",
  required: [
    "job_type",
    "issue_id",
    "severity_score",
    "ward_id",
    "department_id",
    "duplicate_of_issue_id",
    "image_phash",
    "dedup_confidence",
    "processed_at",
  ],
  additionalProperties: false,
  properties: {
    job_type: { type: "string", const: "severity_update" },
    issue_id: { type: "string", format: "uuid", example: "c3d4e5f6-a7b8-9012-cdef-345678901234" },
    severity_score: { type: ["number", "null"], minimum: 0, maximum: 1, example: 0.73 },
    ward_id: { type: ["string", "null"], format: "uuid", example: "d4e5f6a7-b8c9-0123-def0-456789012345" },
    department_id: { type: ["string", "null"], format: "uuid", example: "e5f6a7b8-c9d0-1234-ef01-567890123456" },
    duplicate_of_issue_id: { type: ["string", "null"], format: "uuid", example: null },
    image_phash: { type: ["string", "null"], example: "a1b2c3d4e5f60718" },
    dedup_confidence: { type: ["number", "null"], minimum: 0, maximum: 1, example: null },
    processed_at: { type: "string", format: "date-time", example: "2026-02-15T10:01:30Z" },
  },
} as const;
