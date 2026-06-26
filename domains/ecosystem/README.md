# `ecosystem` domain

Top-level research domain. Leaves live in subfolders, each scaffolded with
`pnpm leaf add ecosystem/<leaf>` (README, PLAN, PROGRESS, STATUS.yaml, extract/, queries/).

## Optional: domain-specific tables

Every domain gets the shared base schema (sources, documents, concepts, commands,
config_keys, failure_modes, relationships). To add domain-specific tables, create
`schema.ecosystem.sql` here using the `{{schema}}` placeholder; `ingest init-db`
applies it on top of the base and leaves cross-domain `meta.*` views untouched.

See `domains/_shared/sessions/extend-playbook.md` for the depth-configurable,
re-engageable research flow.
