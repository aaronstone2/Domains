# Phase 8 — Interview Rehearsal Scenarios

Ten deep multi-turn scenarios covering the breadth of an AI Support Engineer interview at Cognition. Each scenario walks the full conversational arc:

1. Realistic user opening message
2. SE mental model (what to think about in the first 5 seconds)
3. Verified harness queries (`pnpm harness …`) with actual output
4. SE response with citations
5. User follow-up turns
6. Coverage notes (what the scenario tests)
7. Practice notes for interviewer pushback (the "but what about X" questions)

All harness output in these scenarios was verified against the live corpus on 2026-05-03 (767 sources, 1889 concepts, 415 failure_modes, 1551 relationships). If the corpus changes, the rendered output may differ; the queries themselves remain valid.

## Scenarios

| # | Title | Difficulty | Domains | Time-to-resolution |
|---|---|---|---|---|
| [01](01-docker-oom.md) | Container exited with code 137 | entry | docker, linux, k8s | ≤ 3 min |
| [02](02-container-egress-tree.md) | Container can't reach the internet | mid | docker, linux, k8s | ≤ 5 min |
| [03](03-pod-pending.md) | Pod stuck in Pending | mid | k8s | ≤ 4 min |
| [04](04-dns-slow-pod.md) | DNS slow inside pods | mid | k8s, linux, docker | ≤ 3 min |
| [05](05-app-slow-cpu-low.md) | App slow but CPU shows low | advanced | linux, methodology | ≤ 8 min |
| [06](06-devin-internal-svc.md) | Devin can't reach internal staging | mid | devin, linux | ≤ 5 min |
| [07](07-systemd-unit-wont-start.md) | systemd unit won't start | entry-mid | linux | ≤ 4 min |
| [08](08-process-d-state.md) | Process stuck, SIGKILL won't kill it | advanced | linux | ≤ 5 min (diagnosis) |
| [09](09-image-pull-fail.md) | docker pull "unauthorized" | mid | docker, k8s, devin | ≤ 4 min |
| [10](10-postmortem-blame.md) | Our postmortem became a trial | soft-skills | methodology | N/A (multi-day) |

## How to use these as practice material

**Solo practice (15-30 min per scenario):**

1. Read the user opening message; close the file.
2. On a whiteboard or notepad, write down: what's the first command you'd run, and what would you expect to see?
3. Open the file and compare. The "SE mental model" section is the spine — match your reasoning to it.
4. Read through the harness queries and verify they make sense (don't just trust; understand why each query is the right next move).
5. Read the SE response. Note any tools, options, or numbers you didn't know.
6. Read the practice notes for pushback questions — these are the "but what about X" angles that come up in real interviews. For each, draft a 1-sentence answer before reading on.

**Pair practice (30-45 min per scenario):**

1. Partner reads the user opening message aloud.
2. You verbalize your mental model and the first command.
3. Partner reads the user reply (turn 2).
4. Continue through the conversation.
5. Partner asks one of the practice-notes pushback questions; you answer cold.

**Live mock (60+ min, 3-4 scenarios):**

1. Pick scenarios across difficulty levels: one entry, one mid, one advanced, one soft-skills.
2. Run them back-to-back without breaks.
3. Time yourself; the time-to-resolution targets are aggressive but achievable.
4. After: review which scenarios you were slow on, and re-read those specifically.

## Coverage matrix

|  | docker | linux | k8s | devin | methodology | firecracker | ecs |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| S1 (OOM) | ✓ primary | ✓ deep | ✓ secondary | | | | |
| S2 (egress) | ✓ primary | ✓ deep | ✓ secondary | | | | |
| S3 (pending) | | | ✓ primary | | | | |
| S4 (DNS) | ✓ secondary | ✓ deep | ✓ primary | | | | |
| S5 (slow/low CPU) | | ✓ primary | | | ✓ deep | | |
| S6 (Devin VPN) | | ✓ secondary | | ✓ primary | | | |
| S7 (systemd) | | ✓ primary | | | | | |
| S8 (D-state) | | ✓ primary | | | | | |
| S9 (image pull) | ✓ primary | | ✓ secondary | ✓ secondary | | | ✓ secondary |
| S10 (postmortem) | | | | | ✓ primary | | |

Every domain except firecracker and ecs has at least one primary-coverage scenario. Firecracker shows up in the related-walks (S1, S6) but doesn't have a dedicated rehearsal scenario — the interview is a Docker/Linux VM screen-share, so firecracker depth is "useful background" not "expected output."

## Anti-pattern check (what these scenarios avoid)

- **Don't memorize commands; understand mental models.** Every scenario opens with the SE mental model section so the *thinking* is explicit, not just the answer.
- **Don't fix without diagnosing.** Every scenario starts with diagnostic queries before fix steps.
- **Don't overspecify the answer.** The user replies in each turn show how the actual fix depends on their environment; the SE response always asks one clarifying question or offers two paths rather than one prescription.
- **Don't skip citations.** Every command is followed by a doc link; every claim is backed by a source from the corpus.
- **Don't ignore the soft skills.** Scenario 10 demonstrates that the interview will likely include a non-technical scenario; preparation should not be 100% commands.

## Live capture (`harness capture`)

Phase 9 added a `capture` subcommand for running curated diagnostic bundles and getting a single Markdown blob you can paste. List bundles:

```
pnpm harness capture --list
```

Available bundles:

| Bundle | Use when |
|---|---|
| `oom` | container/process killed; suspect memory limit |
| `network-egress` | container can't reach internet/internal |
| `dns` | DNS resolution slow/failing/wrong |
| `systemd-unit` | systemd unit failed to start |
| `k8s-pending` | pod stuck Pending |
| `docker-state` | "docker is broken" — general health snapshot |
| `perf-stalls` | app slow but CPU shows low (off-CPU/IPC investigation) |
| `devin-vpn` | DevBox can't reach internal services |

Or synthesize a bundle from any failure_mode:

```
pnpm harness capture --from-fm <fm-id>
```

Pulls the `diagnostic_steps` out of the playbook automatically. Save to a file:

```
pnpm harness capture oom --output snapshot.md
```

Default redactions: AWS access keys, GitHub PATs, JWTs, password=/token=/api_key= patterns. Per-bundle additional redactions are supported (see `packages/harness/bundles/SCHEMA.md`).

Cross-platform: on Linux runs via `/bin/sh`; on Windows auto-detects WSL → Git Bash → cmd.exe (in that order).

## What's NOT in these scenarios (and why)

- **Real production data.** All examples use placeholder names and made-up timestamps; the realism is in the wording and decision-tree, not in invented log lines.
- **Setup commands.** No "first install bcc-tools." The scenarios assume the SE is talking the user through diagnosis on the user's existing system.
- **Exhaustive coverage of every fm.** The harness has 415 fms; these scenarios touch ~30 of them directly. The rest are 1-command-away via the harness — the point of the harness is that the corpus is the index, not the script.

---

Scenarios are stored alongside the harness so they stay in sync with corpus changes. If a fm gets renamed or deleted, the affected scenario will fail to match its expected output and should be updated.
