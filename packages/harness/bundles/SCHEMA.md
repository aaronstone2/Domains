# Capture bundle schema

A capture bundle is a JSON file with a curated list of diagnostic commands for a specific symptom space (OOM, network egress, DNS, etc.). The harness runs each command, captures stdout+stderr, applies redactions, and emits a single Markdown blob suitable for pasting into a chat.

## File location

`packages/harness/bundles/<name>.json`

The file's basename (minus `.json`) is the bundle ID. `oom.json` → `pnpm harness capture oom`.

## Format

```json
{
  "name": "oom",
  "description": "Memory pressure / OOM kill investigation bundle",
  "platform_hint": "linux-or-wsl",
  "commands": [
    {
      "description": "List recent OOM kills from kernel ring buffer",
      "command": "dmesg -T | grep -i 'killed process' | tail -20",
      "timeout_ms": 5000,
      "allow_failure": true,
      "redact": []
    }
  ]
}
```

### Top-level fields

| Field | Type | Required | Notes |
|---|---|:---:|---|
| `name` | string | ✓ | Display name, often matches filename |
| `description` | string | ✓ | One-sentence summary |
| `platform_hint` | string | ✓ | `linux-or-wsl`, `cross-platform`, `windows-only`, `kubectl-only`, `docker-only` |
| `commands` | array | ✓ | Ordered list of commands to run |

### Per-command fields

| Field | Type | Required | Default | Notes |
|---|---|:---:|---|---|
| `description` | string | ✓ | — | Short label for the section header |
| `command` | string | ✓ | — | Shell command. Run via Bash on Linux/WSL, cmd.exe on Windows. |
| `timeout_ms` | number | | `5000` | Kill the command if it exceeds this. |
| `allow_failure` | boolean | | `true` | If `false`, capture aborts on non-zero exit (rare; usually want best-effort). |
| `redact` | array | | `[]` | Per-command redaction list (added to default redactions). |

## Default redactions (always applied)

Patterns matched case-insensitively against output; replaced with `<REDACTED>`:

| Pattern | Why |
|---|---|
| `AKIA[0-9A-Z]{16}` | AWS access key ID |
| `(?<=:)[A-Za-z0-9/+=]{40}(?=\s|$)` | AWS secret-shaped string |
| `ghp_[A-Za-z0-9]{36}` | GitHub personal access token |
| `eyJ[A-Za-z0-9_=-]+\.eyJ[A-Za-z0-9_=-]+\.[A-Za-z0-9_=-]+` | JWT |
| `(?:Bearer\s+)?[A-Za-z0-9._-]{40,}` | bearer token (heuristic; may have false positives) |

Per-bundle `redact` entries are extended with the bundle's own patterns (e.g. `oom.json` doesn't add new ones; `devin-vpn.json` redacts VPN config snippets).

## Output format

For each command, emit:

```markdown
### <description>

```
<command>
```
exit=N took=Tms

```
<captured output, redacted>
```
```

If a command times out: `(timed out after Nms)` instead of output.
If a command's binary doesn't exist: `(command not available on this system)`.
If `--platform-hint` doesn't match host: a one-line warning at top, but commands still run (best-effort).

## Cross-platform notes

The harness runs on Windows + Linux + macOS. Commands like `dmesg`, `iostat`, `journalctl` are Linux-only. For these:

- On Linux: run directly.
- On WSL-enabled Windows: prefix with `wsl -e bash -c "..."`.
- On bare Windows / macOS: skip with `(command not available on this system)`.

The bundle author shouldn't worry about this — the runtime detects.

For docker/kubectl commands: assume the binaries are in PATH on whatever host. (They often are on dev workstations.)
