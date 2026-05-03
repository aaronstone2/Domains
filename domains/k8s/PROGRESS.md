# k8s — PROGRESS log

Per-domain log; rolls up into `domains/_shared/PROGRESS.md`.

## Phase 1 — Source corpus build-out

### Session 1.1 — 2026-05-03 — DONE

**Outputs:** 62 sources / 4.95 MB indexed in `k8s.sources` / `k8s.documents`. BM25 FTS index `fts_k8s_documents` built.

**Per-subdomain breakdown:**

| subdomain | sources | total chars |
|---|---:|---:|
| debugging | 14 | 4.0 MB (incl 3.88 MB k8s-events API ref) |
| core | 31 | 714 KB |
| networking | 10 | 146 KB |
| runtime | 7 | 95 KB |

**Sources fetched:** 0 failures. All from kubernetes.io (CC BY 4.0, redistribute-ok).

**Net delta:** 6 → 62 entries (+56 new). Existing 6 entries kept; net new across all 4 subdomains.

## Phase 3 — Concepts / Commands / Config-keys

### All 4 leaves COMPLETE in same session — 2026-05-03

| Leaf | concepts | commands | config_keys | total |
|---|---:|---:|---:|---:|
| core | 107 | 16 | 151 | **274** |
| networking | 57 | 10 | 71 | **138** |
| debugging | 54 | 12 | 68 | **134** |
| runtime | 56 | 7 | 69 | **132** |
| **total** | **274** | **45** | **359** | **678** |

**Verified:** 0 orphan source_ids across all 4 leaves (one fix needed: `k8s-cordon` typo → `k8s-debug-cluster` in core leaf).

**Method:** standard duckdb CLI load with `read_json_auto` + explicit STRUCT columns for commands.

**Coverage notes:**
- Skipped extracting from `k8s-events` (3.88 MB API reference dump — would need targeted FTS-slicing per concept; deferred to Phase 1.5)
- All sources T1 from kubernetes.io. No T2 sources used.
- Config_keys densest in core (151 covering pod-spec, deployment, service, RBAC, security-context, eviction signals).

## Cross-references

- Pipe-able session prompts: `domains/_shared/sessions/phase-1-source-corpus.md`, `phase-3-deep-extraction.md`
- Sister-domain precedents: docker (1277 rows), linux (1711 rows), devin (1014 rows), methodology (207 rows)
- All-domains total post-k8s: docker 1277 + linux 1711 + devin 1014 + methodology 207 + k8s 678 = **4887 rows** across `<domain>.{concepts,commands,config_keys}`
