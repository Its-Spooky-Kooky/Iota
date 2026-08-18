"""
IOTA — Queue Event Schemas (Python mirror)

Source of truth: backend/shared/libs/event-schemas/index.ts
This file MUST stay in sync with that file.  Field names, casing, and
nullability are identical between the TS and Python versions — any
divergence silently breaks the queue contract.

FIELD NAMING RULE: all fields snake_case (matching the TS source of truth).

Pydantic v2 is used.  For Pydantic v1 compatibility swap BaseModel import
from pydantic.v1 and replace `model_validate` → `parse_obj`.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import List, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field


# ─────────────────────────────────────────────────────────────────
# Shared / primitive enums
# ─────────────────────────────────────────────────────────────────


class IssueCategory(str, Enum):
    ROAD_DAMAGE = "ROAD_DAMAGE"
    WATERLOGGING = "WATERLOGGING"
    GARBAGE = "GARBAGE"
    STREETLIGHT = "STREETLIGHT"
    SEWAGE = "SEWAGE"
    ENCROACHMENT = "ENCROACHMENT"
    OTHER = "OTHER"


# ─────────────────────────────────────────────────────────────────
# Inbound: backend → ml-service
# ─────────────────────────────────────────────────────────────────


class RoutingJobPayload(BaseModel):
    """
    Enqueued by issue-service immediately after a new issue row is created.
    ml-service uses this to determine ward/department assignment.

    Queue name: "routing_jobs"
    """

    job_type: Literal["routing_job"] = Field(
        ...,
        description="Discriminator — always 'routing_job'.",
    )
    issue_id: UUID = Field(
        ...,
        description="The issue to route.",
        examples=["c3d4e5f6-a7b8-9012-cdef-345678901234"],
    )
    category: IssueCategory = Field(
        ...,
        description="Category drives department-mapping fallback logic.",
        examples=["ROAD_DAMAGE"],
    )
    latitude: float = Field(
        ...,
        ge=-90,
        le=90,
        description="WGS-84 latitude of the reported location.",
        examples=[18.5204],
    )
    longitude: float = Field(
        ...,
        ge=-180,
        le=180,
        description="WGS-84 longitude of the reported location.",
        examples=[73.8567],
    )
    enqueued_at: datetime = Field(
        ...,
        description="ISO-8601 timestamp when this job was enqueued.",
        examples=["2026-02-15T10:00:00Z"],
    )

    model_config = {"extra": "forbid"}


class DedupJobPayload(BaseModel):
    """
    Enqueued by issue-service alongside RoutingJobPayload.
    ml-service uses perceptual hashing, embedding similarity, and geo
    proximity to detect duplicate issues.

    Queue name: "dedup_jobs"
    """

    job_type: Literal["dedup_job"] = Field(
        ...,
        description="Discriminator — always 'dedup_job'.",
    )
    issue_id: UUID = Field(
        ...,
        description="The candidate issue being checked for duplication.",
        examples=["c3d4e5f6-a7b8-9012-cdef-345678901234"],
    )
    category: IssueCategory = Field(
        ...,
        description="Category — used to narrow the dedup search space.",
        examples=["ROAD_DAMAGE"],
    )
    latitude: float = Field(
        ...,
        ge=-90,
        le=90,
        description="WGS-84 latitude of the reported location.",
        examples=[18.5204],
    )
    longitude: float = Field(
        ...,
        ge=-180,
        le=180,
        description="WGS-84 longitude of the reported location.",
        examples=[73.8567],
    )
    photo_urls: List[str] = Field(
        ...,
        description="Public URLs of the issue's photos. May be empty.",
        examples=[["https://cdn.iota.app/issues/photo_abc123.webp"]],
    )
    description: str = Field(
        ...,
        min_length=0,
        max_length=1000,
        description="Client-generated description text; used for text-embedding similarity.",
        examples=["Large pothole near Shivaji Market."],
    )
    enqueued_at: datetime = Field(
        ...,
        description="ISO-8601 timestamp when this job was enqueued.",
        examples=["2026-02-15T10:00:00Z"],
    )

    model_config = {"extra": "forbid"}


# ─────────────────────────────────────────────────────────────────
# Outbound: ml-service → backend (routing-service / issue-service)
# ─────────────────────────────────────────────────────────────────


class SeverityUpdatePayload(BaseModel):
    """
    Published by ml-service after processing both RoutingJobPayload and
    DedupJobPayload for an issue.  routing-service consumes this and
    applies the update to the issue row via issue-service.

    Queue name: "ml_results"
    """

    job_type: Literal["severity_update"] = Field(
        ...,
        description="Discriminator — always 'severity_update'.",
    )
    issue_id: UUID = Field(
        ...,
        description="The issue this result applies to.",
        examples=["c3d4e5f6-a7b8-9012-cdef-345678901234"],
    )
    severity_score: Optional[float] = Field(
        ...,
        ge=0.0,
        le=1.0,
        description=(
            "Severity score in the range [0.0, 1.0]. Higher = more severe. "
            "None if scoring model failed (non-fatal)."
        ),
        examples=[0.73],
    )
    ward_id: Optional[UUID] = Field(
        ...,
        description=(
            "Ward UUID determined by geo lookup against the wards table. "
            "None if lookup failed."
        ),
        examples=["d4e5f6a7-b8c9-0123-def0-456789012345"],
    )
    department_id: Optional[UUID] = Field(
        ...,
        description=(
            "Department UUID determined by category -> department mapping. "
            "None if lookup failed."
        ),
        examples=["e5f6a7b8-c9d0-1234-ef01-567890123456"],
    )
    duplicate_of_issue_id: Optional[UUID] = Field(
        ...,
        description=(
            "If this issue is a duplicate, the UUID of the canonical (original) issue. "
            "None means not a duplicate."
        ),
        examples=[None],
    )
    image_phash: Optional[str] = Field(
        ...,
        description=(
            "Perceptual hash of the first attached photo (pHash, hex string). "
            "None if no photos were attached."
        ),
        examples=["a1b2c3d4e5f60718"],
    )
    dedup_confidence: Optional[float] = Field(
        ...,
        ge=0.0,
        le=1.0,
        description=(
            "Confidence score for the duplicate decision [0.0, 1.0]. "
            "None when duplicate_of_issue_id is None."
        ),
        examples=[None],
    )
    processed_at: datetime = Field(
        ...,
        description="ISO-8601 timestamp when ml-service published this result.",
        examples=["2026-02-15T10:01:30Z"],
    )

    model_config = {"extra": "forbid"}


# ─────────────────────────────────────────────────────────────────
# Union for generic deserialization at the consumer
# ─────────────────────────────────────────────────────────────────

from typing import Union, Annotated
from pydantic import Discriminator, Tag

InboundJob = Annotated[
    Union[
        Annotated[RoutingJobPayload, Tag("routing_job")],
        Annotated[DedupJobPayload, Tag("dedup_job")],
    ],
    Discriminator("job_type"),
]
"""
Use InboundJob as the deserialization target in consumer.py:

    import json
    from pydantic import TypeAdapter

    _adapter = TypeAdapter(InboundJob)

    def parse_job(raw: bytes) -> RoutingJobPayload | DedupJobPayload:
        return _adapter.validate_json(raw)
"""
