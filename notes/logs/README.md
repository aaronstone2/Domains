# notes/logs/ — raw paste

Drop logs, errors, command output, customer tickets here. Filename:
`YYYY-MM-DD-HHMM-shortname.log` so they sort by recency. Everything in
this directory is gitignored except this README.

```bash
# Pipe diagnostic output:
bash bash/debug/oom.sh staff-tls > notes/logs/$(date +%F-%H%M)-oom.log

# Quick paste:
nano notes/logs/$(date +%F-%H%M)-redis-error.log

# Find latest:
ls -t notes/logs/ | head -5
```
