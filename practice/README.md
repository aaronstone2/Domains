# Practice scenarios — real broken-system simulators

Each script in this directory creates an actual broken state on the local Linux box (or in a container) so you can practice debugging with `claude` + the harness against real symptoms instead of narrative prompts.

## Usage pattern

```bash
./practice/01-disk-pressure.sh start    # break something
# ... debug it with `ha "<symptom>"`, claude, etc. Time yourself.
./practice/01-disk-pressure.sh restore  # undo
```

## Workflow

1. Open two terminals: one running `claude` in the repo root, one for free-form shell.
2. Pick a scenario — don't read its hints/answers section first.
3. Run `./practice/<NN>-<name>.sh start`. Read the printed scenario description.
4. **Time yourself.** Use the harness to find the failure mode. Use `claude` to walk through diagnostic + fix steps.
5. When you think you're done, run the script's `verify` arg to confirm you actually fixed it.
6. Run `restore` to clean up. Move to the next scenario.
7. Compare your time + approach against the script's `--reveal` notes.

## Scenarios

| # | Script | Triggers | Needs |
|---:|---|---|---|
| 01 | `01-disk-pressure.sh` | Filesystem / disk-full debugging | nothing |
| 02 | `02-hung-process.sh` | Process stuck on I/O (D-state-like) | nothing |
| 03 | `03-memory-pressure.sh` | OOM-killer / memory-pressure investigation | nothing |
| 04 | `04-bad-systemd-unit.sh` | systemd unit failed to start | systemctl --user OR sudo |
| 05 | `05-port-collision.sh` | Service can't bind: port already in use | nothing |
| 06 | `06-docker-oom.sh` | Container exit 137 / OOMKilled | docker |
| 07 | `07-docker-no-egress.sh` | Container can't reach internet | docker |
| 08 | `08-bad-resolv.sh` | DNS lookups failing inside container | docker |

Scripts that need docker check for it and exit cleanly if absent. Scripts that need sudo prompt explicitly.

## Safety contract

- Every script is **idempotent**: running `start` twice is fine; `restore` always cleans up to the original state.
- No script touches `/`, `/etc`, or any system files outside what's explicitly noted in its header.
- All scratch state lives under `/tmp/domains-practice/` so a `rm -rf /tmp/domains-practice` recovers from anything.
- Container scenarios use prefix `domains-practice-` so `docker rm -f $(docker ps -aq -f name=domains-practice-)` cleans up.

## Suggested order for first pass

1. **05-port-collision** (~5 min) — lowest stakes, builds harness familiarity
2. **01-disk-pressure** (~10 min) — classic SE scenario
3. **04-bad-systemd-unit** (~10 min) — systemd flow
4. **06-docker-oom** (~15 min) — most-likely-asked interview scenario
5. **07-docker-no-egress** (~15 min) — networking layer-by-layer
6. **08-bad-resolv** (~15 min) — DNS specifically

Skip 02-hung-process and 03-memory-pressure on first pass; circle back if you want more reps.

## Extending

To add a scenario, copy `_template.sh` and fill in the four functions:
`start`, `restore`, `verify`, `reveal`. Add a row to the table above.
