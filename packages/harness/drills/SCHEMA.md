# Drill scenario schema

A drill scenario is a JSON file used by `harness drill` to play back an interview-style scenario as an interactive practice exercise. Derived from the markdown rehearsal scenarios at `domains/_shared/rehearsal/scenarios/`.

## File location

`packages/harness/drills/<id>.json`

`<id>` matches the markdown scenario's number-prefixed slug, e.g. `01-docker-oom`.

## Format

```json
{
  "id": "01-docker-oom",
  "title": "Container exited with code 137",
  "difficulty": "entry",
  "domains": ["docker", "linux", "k8s"],
  "primary_fm": "docker.fm.exit-137-oomkilled",
  "scenario_md": "domains/_shared/rehearsal/scenarios/01-docker-oom.md",
  "turns": [
    {
      "user_message": "Hey, I've got a container that keeps exiting with code 137...",
      "se_response_summary": "137 = SIGKILL. Most likely cgroup OOM. Run docker inspect, dmesg, check memory limit.",
      "expected_harness_commands": [
        "lookup",
        "playbook docker.fm.exit-137-oomkilled"
      ],
      "expected_keywords": [
        "OOMKilled",
        "dmesg",
        "memory.events",
        "--memory",
        "cgroup"
      ],
      "hints": [
        "What does '137' decode to as a signal?",
        "Where does 'OOMKilled=true' show up in docker?",
        "Which file in /sys/fs/cgroup tracks OOM events?"
      ]
    }
  ]
}
```

### Top-level fields

| Field | Type | Notes |
|---|---|---|
| `id` | string | Matches markdown filename slug |
| `title` | string | Scenario title |
| `difficulty` | string | `entry` / `mid` / `advanced` / `soft-skills` |
| `domains` | array | Which corpus domains exercised |
| `primary_fm` | string\|null | Canonical fm-id if any |
| `scenario_md` | string | Path to full scenario markdown for "show full answer" |
| `turns` | array | Conversation turns the user practices on |

### Per-turn fields

| Field | Type | Notes |
|---|---|---|
| `user_message` | string | Quoted user input the SE has to respond to |
| `se_response_summary` | string | One-paragraph canonical SE response (terse) |
| `expected_harness_commands` | array | Commands like `"playbook X"`, `"lookup Y"`, `"related Z"` |
| `expected_keywords` | array | Concepts/commands/file-paths that should appear in the SE's response |
| `hints` | array | Progressive hints if the user asks for help |

## How `harness drill` uses this

1. **Pick a scenario** (named or random).
2. **Show turn 1's `user_message`** — print it like an incoming chat.
3. **Wait for stdin** — user types their response (multiple lines, terminate with `.\n` or EOF).
4. **Score:**
   - Check which `expected_harness_commands` they mentioned (substring match).
   - Check which `expected_keywords` they mentioned.
   - Print "you covered N/M expected items."
5. **Reveal `se_response_summary`** so they can compare.
6. **Repeat** for turn 2, etc.
7. **Final summary:** total coverage, list missed keywords across all turns, link to full markdown.

This is "playback with pause" — not auto-grading. The user reads their own response and the canonical, and learns by comparison.

## Special inputs during a turn

- `hint` — print the next progressive hint
- `skip` — skip this turn, no scoring
- `quit` — exit drill
- `show` — reveal the canonical response without scoring (gives up)
