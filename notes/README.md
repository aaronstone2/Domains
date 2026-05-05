# notes/ — local scratch (gitignored)

Personal scratch space. Paste logs and reports here, then ask the AI to read them.

## Layout

```
notes/
├── logs/      # raw paste — command output, errors, metrics, customer ticket text
└── reports/   # synthesized — RCA writeups, Devin session summaries
```

## Conventions

- **Single inbox per category.** No need to file by topic at paste time.
- **Filename = `YYYY-MM-DD-HHMM-shortname.{log,md}`** so files sort by recency.
- **All gitignored.** Stays local; promote to repo if it deserves to ship.

## Workflow

```bash
# Paste a log
nano notes/logs/$(date +%F-%H%M)-redis-error.log

# Or pipe diagnostic output
bash bash/debug/oom.sh staff-tls > notes/logs/$(date +%F-%H%M)-oom.log

# Then ask AI:
#   "look at the latest log in notes/logs/"
#   "read notes/logs/2026-05-05-1830-redis-error.log"
```
