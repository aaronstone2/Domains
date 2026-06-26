from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Tier = Literal["T0", "T1", "T2", "T3"]
License = Literal["redistribute-ok", "reference-only", "unknown"]
EvidenceClass = Literal["primary", "secondary", "tertiary", "synthetic"]
PrimaryKind = Literal[
    "ab-test", "pref-test", "usability", "telemetry", "review-mining", "interview", "survey"
]


class Source(BaseModel):
    """A discoverable source of truth (URL + metadata). Mirrors `<domain>.sources` row."""

    model_config = ConfigDict(extra="forbid")

    id: str
    url: str
    domain: str
    tier: Tier
    title: str | None = None
    subdomain: str | None = None
    license_note: License = "unknown"
    parser: str = "trafilatura"
    fetched_at: datetime | None = None
    content_hash: str | None = None
    notes: str = ""
    # Layer 1 — primary-evidence tier. Default 'secondary': analyst/docs/blogs are not behavioral
    # evidence. Only real captures (review-mining, A/B, usability, telemetry) are 'primary'.
    evidence_class: EvidenceClass = "secondary"
    primary_kind: PrimaryKind | None = None


class Document(BaseModel):
    """One block of cleaned markdown extracted from a source. Mirrors `<domain>.documents`."""

    model_config = ConfigDict(extra="forbid")

    source_id: str
    section_path: str
    content_md: str


class SourcesFile(BaseModel):
    """Top-level shape of `domains/_shared/sources.yaml`."""

    model_config = ConfigDict(extra="forbid")

    sources: list[Source] = Field(default_factory=list)
