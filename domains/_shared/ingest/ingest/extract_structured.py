"""LLM-driven structured extraction.

For each (source × target table) we ask Claude to emit a list of rows shaped
like the DuckDB DDL via tool_use. We force tool use, parse the single
``tool_use`` block, stamp the source's ID into each row's ``source_ids`` list,
and merge into the leaf's ``extract/<table>.json`` file by row ID. Re-runs are
idempotent — duplicate IDs upsert.

The motherduck MCP then loads the JSON via ``INSERT OR REPLACE BY NAME ... SELECT
* FROM read_json(...)`` (with an explicit ``columns`` spec for the STRUCT-typed
``commands`` table). See ``domains/_shared/sessions/phase-3-deep-extraction.md``.

This module is the long-tail extractor that pays off in docker/linux/devin
where the corpora are multi-MB; methodology validates the schema and ID shape.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Literal

import anthropic
import duckdb

from ingest.paths import DB_PATH, DOMAINS_DIR

MODEL = "claude-opus-4-7"
MAX_TOKENS = 16_000

# Truncate doc content to fit comfortably under Opus 4.7's input window. The
# largest methodology doc is brendangregg-perf at ~210 KB (~50K tokens), well
# under this limit. Future docker/linux docs may need chunking.
MAX_DOC_CHARS = 350_000

Table = Literal["concepts", "commands", "config_keys"]


CONCEPTS_TOOL: dict = {
    "name": "record_concepts",
    "description": (
        "Record concepts (frameworks, tools, techniques, metrics, roles, "
        "template-fields) found in this debugging-corpus source document. "
        "One row per distinct named concept. Be faithful to how the source "
        "describes it — do not invent."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "concepts": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": (
                                "Stable kebab-cased ID. Format: <domain>.<kebab-name>. "
                                "Examples: 'methodology.use-method', "
                                "'methodology.four-golden-signals', "
                                "'methodology.off-cpu-analysis'."
                            ),
                        },
                        "name": {
                            "type": "string",
                            "description": "Human-readable concept name as it appears in the source.",
                        },
                        "kind": {
                            "type": "string",
                            "description": (
                                "Category. Use one of: framework, tool, technique, "
                                "metric, role, template-field, concept."
                            ),
                        },
                        "description": {
                            "type": "string",
                            "description": (
                                "1–3 sentence definition. Faithful to how the source "
                                "describes the concept."
                            ),
                        },
                        "aliases": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Other names used for this concept in the source.",
                        },
                    },
                    "required": ["id", "name", "description"],
                },
            }
        },
        "required": ["concepts"],
    },
}


COMMANDS_TOOL: dict = {
    "name": "record_commands",
    "description": (
        "Record CLI commands documented in this source. One row per distinct "
        "command form (e.g. 'perf record', 'perf stat', 'perf script' are "
        "three rows). Capture flags + at least one concrete example invocation."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "commands": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": (
                                "Stable ID. Format: <domain>.cmd.<tool>.<form>. "
                                "Examples: 'methodology.cmd.perf.record', "
                                "'methodology.cmd.bpftrace.kprobe', "
                                "'methodology.cmd.flamegraph.fold-stacks'."
                            ),
                        },
                        "command": {
                            "type": "string",
                            "description": (
                                "The command form as users invoke it, e.g. "
                                "'perf record' or 'bpftrace -e <probe-spec>'."
                            ),
                        },
                        "purpose": {
                            "type": "string",
                            "description": "1–2 sentences: what it does and when to reach for it.",
                        },
                        "flags": {
                            "type": "array",
                            "description": "Notable flags. Each: name, value (or null for boolean), doc.",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "name": {"type": "string", "description": "Flag string, e.g. '-F' or '--call-graph'."},
                                    "value": {"type": ["string", "null"], "description": "Argument shape, e.g. '<freq>' or null for boolean."},
                                    "doc": {"type": "string", "description": "What the flag does."},
                                },
                                "required": ["name", "doc"],
                            },
                        },
                        "examples": {
                            "type": "array",
                            "description": "Concrete invocations. Include at least one if any are documented.",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "invocation": {"type": "string", "description": "The full command line."},
                                    "expected_output": {"type": ["string", "null"], "description": "Brief description of what it produces."},
                                    "scenario": {"type": ["string", "null"], "description": "When you'd run this — e.g. 'CPU saturation drill'."},
                                },
                                "required": ["invocation"],
                            },
                        },
                    },
                    "required": ["id", "command", "purpose"],
                },
            }
        },
        "required": ["commands"],
    },
}


CONFIG_KEYS_TOOL: dict = {
    "name": "record_config_keys",
    "description": (
        "Record configuration keys, template fields, or schema fields documented in "
        "this source. One row per field. Use 'scope' to group related fields, e.g. "
        "scope='postmortem-template' for postmortem fields, scope='slo' for SLO config."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "config_keys": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": (
                                "Stable ID. Format: <domain>.cfg.<scope>.<key>. "
                                "Examples: 'methodology.cfg.postmortem-template.action-items', "
                                "'methodology.cfg.slo.error-budget-rate'."
                            ),
                        },
                        "scope": {
                            "type": "string",
                            "description": (
                                "Group/scope. E.g. 'postmortem-template', 'slo', "
                                "'four-golden-signals', 'use-method'."
                            ),
                        },
                        "key": {
                            "type": "string",
                            "description": "Field name as named in the source.",
                        },
                        "type": {
                            "type": "string",
                            "description": (
                                "Field type. E.g. 'string', 'number', 'boolean', "
                                "'list', 'list[struct]', 'enum', 'datetime'."
                            ),
                        },
                        "default_value": {
                            "type": ["string", "null"],
                            "description": "Default if specified; null otherwise.",
                        },
                        "description": {
                            "type": "string",
                            "description": "1–3 sentences faithful to the source.",
                        },
                    },
                    "required": ["id", "scope", "key", "description"],
                },
            }
        },
        "required": ["config_keys"],
    },
}


_TOOLS: dict[Table, dict] = {
    "concepts": CONCEPTS_TOOL,
    "commands": COMMANDS_TOOL,
    "config_keys": CONFIG_KEYS_TOOL,
}


def _system_prompt(domain: str, table: Table) -> str:
    return (
        f"You are extracting structured rows for a multi-domain debugging knowledge corpus.\n"
        f"Your output populates the DuckDB table `{domain}.{table}` and is queried at runtime by an interview-prep harness.\n\n"
        f"Domain: {domain}\n"
        f"Table: {table}\n\n"
        "BE FAITHFUL TO THE SOURCE. Do not invent concepts, commands, or fields. "
        "If a concept is named explicitly in the source, use that name; if a command's purpose is described, paraphrase tightly.\n\n"
        "ID convention (deterministic — re-extracting the same source must produce the same IDs):\n"
        "- concepts: `<domain>.<kebab-name>` — e.g. 'methodology.use-method', 'methodology.four-golden-signals'.\n"
        "- commands: `<domain>.cmd.<tool>.<form>` — e.g. 'methodology.cmd.perf.record', 'methodology.cmd.bpftrace.kprobe'.\n"
        "- config_keys: `<domain>.cfg.<scope>.<key>` — e.g. 'methodology.cfg.postmortem-template.action-items'.\n\n"
        "Output rules:\n"
        "- Use kebab-case for the variable parts of IDs. Lowercase only.\n"
        "- For concepts/commands, focus on items the source defines explicitly or treats as a discrete topic.\n"
        "- Skip mere mentions and asides.\n"
        "- For commands, prefer one row per (tool, subcommand) pair (e.g. `perf record` and `perf stat` are separate).\n"
        "- For config_keys, only emit rows when the source documents a field with a clear scope (e.g. SRE postmortem template fields, SLO definition fields).\n\n"
        "Use the supplied tool to record your findings. Do not produce free-form text alongside the tool call."
    )


def extract_from_document(
    *,
    domain: str,
    table: Table,
    source_id: str,
    source_title: str,
    content_md: str,
    client: anthropic.Anthropic | None = None,
) -> list[dict]:
    """Run one extraction call for one (source × table). Returns raw rows from the model.

    Caller is responsible for stamping ``source_ids`` and merging by ID.
    """
    client = client or anthropic.Anthropic()
    tool = _TOOLS[table]
    truncated = content_md[:MAX_DOC_CHARS]
    truncation_note = (
        ""
        if len(content_md) <= MAX_DOC_CHARS
        else f"\n\n[NOTE: source truncated from {len(content_md)} to {MAX_DOC_CHARS} chars; "
        "if entities surface only after the cutoff they will be missed]"
    )

    response = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=[
            {
                "type": "text",
                "text": _system_prompt(domain, table),
                "cache_control": {"type": "ephemeral"},
            }
        ],
        tools=[{**tool, "cache_control": {"type": "ephemeral"}}],
        tool_choice={"type": "tool", "name": tool["name"]},
        messages=[
            {
                "role": "user",
                "content": (
                    f"Source ID: {source_id}\n"
                    f"Title: {source_title}\n\n"
                    f"--- BEGIN SOURCE ---\n{truncated}{truncation_note}\n--- END SOURCE ---"
                ),
            }
        ],
    )

    for block in response.content:
        if block.type == "tool_use":
            payload = block.input
            return list(payload.get(table, []))
    raise RuntimeError(f"No tool_use block in response for source_id={source_id}")


def _resolve_out_path(domain: str, subdomain: str, table: Table, override: Path | None) -> Path:
    if override is not None:
        return override
    return DOMAINS_DIR / domain / subdomain / "extract" / f"{table}.json"


def _load_existing(out_path: Path) -> dict[str, dict]:
    if not out_path.is_file() or out_path.stat().st_size == 0:
        return {}
    try:
        rows = json.loads(out_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return {r["id"]: r for r in rows if isinstance(r, dict) and "id" in r}


def _merge_rows(
    existing: dict[str, dict],
    new_rows: list[dict],
    source_id: str,
) -> int:
    """Stamp source_id and merge by ID. Returns net count added/updated."""
    n = 0
    for row in new_rows:
        if "id" not in row:
            continue
        prior = existing.get(row["id"], {})
        prior_sources = list(prior.get("source_ids", []))
        merged_sources = list(dict.fromkeys([*prior_sources, source_id]))
        merged_row = {**prior, **row, "source_ids": merged_sources}
        existing[row["id"]] = merged_row
        n += 1
    return n


def run_for_subdomain(
    *,
    domain: str,
    subdomain: str,
    table: Table,
    source_ids_filter: list[str] | None = None,
    out_path: Path | None = None,
) -> Path:
    """Extract `table` rows for every source in (domain, subdomain).

    If ``source_ids_filter`` is provided, restrict to those source IDs.
    Output is the array-form JSON at ``domains/<domain>/<subdomain>/extract/<table>.json``
    (or ``out_path`` if given). Re-runs upsert by row ID.
    """
    out_path = _resolve_out_path(domain, subdomain, table, out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    existing = _load_existing(out_path)

    con = duckdb.connect(str(DB_PATH), read_only=True)
    try:
        rows = con.execute(
            f"""
            SELECT s.id AS source_id, s.title, d.content_md
            FROM {domain}.sources s
            JOIN {domain}.documents d ON d.source_id = s.id
            WHERE s.subdomain = ?
            ORDER BY length(d.content_md) DESC
            """,
            [subdomain],
        ).fetchall()
    finally:
        con.close()

    if source_ids_filter:
        wanted = set(source_ids_filter)
        rows = [r for r in rows if r[0] in wanted]

    if not rows:
        suffix = f" filter={source_ids_filter}" if source_ids_filter else ""
        raise RuntimeError(
            f"No documents found for {domain}.{subdomain}{suffix}"
        )

    client = anthropic.Anthropic()
    print(
        f"# extracting {table} from {len(rows)} source(s) in {domain}/{subdomain} "
        f"(existing rows: {len(existing)})"
    )
    total_processed = 0
    for source_id, title, content_md in rows:
        title = title or source_id
        try:
            new_rows = extract_from_document(
                domain=domain,
                table=table,
                source_id=source_id,
                source_title=title,
                content_md=content_md,
                client=client,
            )
        except (anthropic.APIError, RuntimeError) as exc:
            print(f"FAIL {source_id}: {type(exc).__name__}: {exc}")
            continue
        n = _merge_rows(existing, new_rows, source_id)
        total_processed += n
        print(
            f"OK   {source_id}: +{len(new_rows)} {table} rows "
            f"({n} merged; total file: {len(existing)})"
        )

    out_path.write_text(
        json.dumps(list(existing.values()), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"# wrote {len(existing)} {table} rows to {out_path.relative_to(DOMAINS_DIR.parent)}")
    return out_path
