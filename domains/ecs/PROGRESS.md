# `ecs` — PROGRESS log

Per-domain progress for the AWS ECS (on bare-metal EC2) knowledge domain.
Phase plans live in `_PHASE-1-PLAN.md` (per phase). Per-leaf detail in `<leaf>/PROGRESS.md`.

## Phase 1 — Source corpus build-out

### Session 1.2 — 2026-05-02 — DONE

**Scope decision**: Added together with `firecracker` per session plan (`~/.claude/plans/purring-pondering-gosling.md`). ECS bare-metal coverage is for substrate-comparison context (containers-on-bare-metal vs in-microVMs), not directly Devin-relevant — but the Nitro System layer is a clean cross-link to `firecracker.kvm`.

**Outputs:**

- 21 / 21 sources fetched, staged, loaded into `ecs.{sources,documents}`. Mean 18,240 chars/doc. 0 fetch failures. Largest: ecs-agent-changelog (121k), ecs-dg-task-defs-params (87k), ecs-dg-service-defs-params (44k), ecs-agent-readme (37k), ecs-dg-optimized-ami (17k).
- BM25 FTS index `fts_ecs_documents` built. 4 verification queries pass.
- 6 leaves scaffolded via `pnpm leaf add`: launch-types (3 sources), task-defs (2), agent (8 incl. amazon-ecs-agent + amazon-ecs-init READMEs/CHANGELOG/proposals), networking (1 + 2 from agent's `proposals/` dir), nitro-baremetal (4 incl. AWS bare-metal + Nitro + nested-virt docs), troubleshooting (1).
- `paths.py:DOMAIN_SCHEMAS` and `queries/cross_domain.sql:meta.all_*` views extended.

**Known thin docs (3, non-blocking):**

- `ecs-dg-agent`, `ecs-dg-agent-update`, `ecs-dg-capacity-providers` returned 0 chars under trafilatura. These are AWS Developer Guide *hub pages* whose main content is just intro + section nav (links out to sub-pages). Trafilatura's main-content detection drops them as boilerplate. Phase 1.5 follow-up: replace with sub-page URLs OR add a playwright fallback OR custom AWS-docs parser. For now, surrounding sources cover the conceptual ground (e.g., `ecs-dg-instance-draining`, `ecs-dg-agent-config` cover the nearby topics).

**Verified:**

- FTS Q6 (awsvpc ENI) → ecs-agent-changelog top-1 (3.106), ecs-dg-task-networking #2
- FTS Q7 (agent registration) → ecs-agent-changelog top-1, ecs-dg-agent-config #3 (in top-5)
- FTS Q8 (bare metal Nitro) → ecs-ec2-nitro top-1 (6.991), ecs-aws-baremetal-announce #4
- Single-term `metal` → ecs-aws-baremetal-announce top-1, ecs-ec2-nitro #2
- Substring: ecs-dg-task-networking has `awsvpc` AND `bridge` ✓
- meta.all_documents includes ecs (21 rows)

**Substring miss (non-blocker):**

- `ecs-agent-readme` does NOT contain `ECS_CONTAINER_INSTANCE_ARN` literal — README links out to docs rather than inlining env vars. `ecs-dg-agent-config` (3,390 chars) is the canonical env-var reference and is loaded.

**Infra changes (this session, shared with firecracker):**

- See `domains/firecracker/PROGRESS.md` for shared infra changes (paths.py, cross_domain.sql, FK gotcha, MCP cleanup).

**Deferred:**

- 3 0-char hub-page sources — sub-page replacement OR playwright fallback in Phase 1.5.
- ECS Best Practices Guide deep ingest (only the index landed; sub-pages deferred).
- ECS Managed Instances (newer 2024 launch type) — not in Phase 1 MVP; add when needed.
- `relationships` rows — Phase 5.

**Next:** `firecracker` Phase 3 first (higher-leverage interview-prep). `ecs` Phase 3 follows. Recommended ecs leaf order when we get there: `agent` → `nitro-baremetal` → `task-defs` → `networking` → `launch-types` → `troubleshooting`.
