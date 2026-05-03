# Phase 1 — `firecracker` source corpus

**Session 1.2 — 2026-05-02 — DONE.** Master plan: `~/.claude/plans/purring-pondering-gosling.md`.

## Context

Aaron's interview at Cognition (Devin.ai) for AI Support Engineer. Cross-cutting research surfaced cognition.ai/blog/what-we-learned-building-cloud-agents — Cognition describes microVM isolation + hypervisor-level snapshots for Devin sessions. Pattern matches Firecracker (without naming it). Deep Firecracker coverage is therefore strong-hint interview-relevant; the Phase-3 vertical for this domain will mine these sources for concepts that map to Devin's likely architecture.

## What landed

- **Domain folder**: `domains/firecracker/` with 10 leaves: `vmm`, `jailer`, `snapshots`, `networking`, `vsock`, `api`, `kvm`, `security`, `setup`, `comparable-systems`. All scaffolded via `pnpm leaf add` (idempotent).
- **Schema**: `firecracker.{sources, documents, concepts, commands, config_keys, failure_modes, relationships}` created via `ingest init-db`. Wired into `paths.py:DOMAIN_SCHEMAS` and `queries/cross_domain.sql:meta.all_*` views.
- **Sources**: 35 of 39 `sources.yaml` entries fetched, staged, and loaded. 4 known failures (e2b sub-page URLs flagged TODO-verify in plan — the canonical ones e2b-repo-readme, e2b-infra-readme, e2b-docs-overview, e2b-blog-architecture all landed cleanly).
- **FTS**: `fts_firecracker_documents` BM25 index built. All 5 verification queries return predicted top-1 in top-3 with strong scores.
- **Mean content length**: 21,530 chars/doc (target >2000). 0 thin docs (<500).

## Verification — all PASS

| Check | Result |
|---|---|
| `count(firecracker.sources)` | 35 (39 attempted, 4 e2b TODO failures) |
| `count(firecracker.documents)` | 35 |
| `avg(length(content_md))` | 21,530 chars |
| Thin docs (<500 chars) | 0 |
| Largest: kvm-api | 323,269 chars (target >100k) ✓ |
| fc-nsdi20-paper PDF | 78,589 chars (target >50k) ✓ |
| FTS Q1 jailer | top-1 fc-docs-jailer (6.353) ✓ |
| FTS Q2 snapshot | top-1 fc-docs-snapshot-support (6.189) ✓ |
| FTS Q3 vsock | top-1 fc-docs-vsock (5.687) ✓ |
| FTS Q4 KVM_RUN | top-1 kvm-api (6.414) ✓ |
| FTS Q5 NSDI signature | top-1 fc-nsdi20-paper (6.743) ✓ |
| Single-term `KVM_RUN` | top-1 kvm-api ✓ |
| `fc-swagger-spec` contains "openapi"/"swagger" | true ✓ |
| `meta.all_documents` includes firecracker | 35 rows visible ✓ |

## Known failures + follow-up

- **4 e2b sub-page URLs returned HTTP error**: `e2b-docs-sandbox-overview`, `e2b-docs-sandbox-lifecycle`, `e2b-docs-filesystem`, `e2b-docs-commands`. All flagged TODO-verify in the plan. Action: WebSearch e2b docs site for current URL structure (likely they restructured the docs paths) and re-run fetch with corrected URLs in a Phase-1 follow-up. Non-blocking — the 4 verified e2b sources still cover the comparable-systems angle.
- **No PDF-extraction issues** for fc-nsdi20-paper (78KB extracted, healthy).

## Phase-5 relationship rows (to write later, after Phase 3 mints concept IDs)

| from_id | to_id | rel_type | source_id | confidence |
|---|---|---|---|---|
| `aws-lambda` | `firecracker-vmm` | `runs-on` | `fc-aws-announce-2018` | definitive |
| `aws-fargate` | `firecracker-vmm` | `runs-on` | `fc-aws-fargate-dataplane` | definitive |
| `devin-devbox` | `microvm-isolation-pattern` | `implements-pattern-of` | `devin-cognition-cloud-agents` | strong-hint |
| `devin-devbox` | `firecracker-vmm` | `likely-uses` | `devin-cognition-cloud-agents` | speculation |
| `e2b-sandbox` | `firecracker-vmm` | `runs-on` | `e2b-infra-readme` | definitive |
| `firecracker-jailer` | `linux-seccomp` | `uses` | `fc-docs-seccomp` | definitive |
| `firecracker-jailer` | `linux-cgroups-v2` | `uses` | `fc-docs-jailer` | definitive |
| `firecracker-vmm` | `kvm-api` | `uses-ioctl-surface-of` | `kvm-api` + `fc-docs-design` | definitive |

## Next: Phase 3 (`firecracker` deep extraction)

Per the vertical-slice convention, the next session continues into `phase-3-deep-extraction.md` for the SAME domain. Recommended leaf order:

1. **`vmm`** — design, getting-started, metrics, logger, cpu-templates (~5 sources, the orientation pass)
2. **`jailer`** — chroot, seccomp, seccompiler, kernel-policy (the Cognition-aligned security layer)
3. **`snapshots`** — snapshot-support, page-faults, network-clones, versioning (the Cognition-aligned subsystem)
4. **`comparable-systems`** — e2b README + infra README + docs landing (mine concepts that proxy Devin's likely architecture)
5. **`networking`** + **`vsock`** + **`api`** + **`kvm`** + **`security`** + **`setup`** — fill out the rest

End-condition for the firecracker vertical: `pnpm harness <query>` returns concept rows with cited source_ids for the Firecracker debugging vocabulary (microVM lifecycle / jailer security boundary / snapshot pause-resume / vsock guest-host / KVM ioctl surface / etc.).
