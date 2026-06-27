#!/usr/bin/env python
"""Render the routine markdown docs in output/ -> styled .html -> .pdf (Chrome/Edge headless).

Each routine lives at output/<lifter>-<gym>.md (e.g. output/mark-290-revolution.md).
This renders every such doc to output/<name>.html + output/<name>.pdf next to it.
README.md (the index) is skipped.

Usage (from anywhere):
  uv run --with markdown python domains/exercise/routine/render.py            # render all routines
  uv run --with markdown python domains/exercise/routine/render.py aaron-290-revolution mark-290-revolution
      # render only the named doc(s) (with or without the .md extension)

Re-run after editing any output/*.md to refresh its printable PDF.
"""
import subprocess
import sys
from pathlib import Path

import markdown

HERE = Path(__file__).parent
OUT = HERE / "output"
SKIP = {"README"}  # the index, not a routine

CSS = """
@page { size: Letter; margin: 0.55in 0.5in; }
* { box-sizing: border-box; }
body { font-family: -apple-system,'Segoe UI',Helvetica,Arial,sans-serif; color:#1b1f24; line-height:1.5;
       font-size:10.5pt; margin:0; -webkit-print-color-adjust:exact; print-color-adjust:exact; }
h1 { font-size:22pt; border-bottom:3px solid #2563eb; padding-bottom:6px; margin:0 0 10px; color:#0f172a; }
h2 { font-size:15pt; margin:22px 0 8px; color:#1d4ed8; border-bottom:1px solid #e2e8f0; padding-bottom:4px; break-after:avoid; }
h3 { font-size:12.5pt; margin:16px 0 6px; color:#0f172a; background:#f1f5f9; padding:5px 8px; border-left:4px solid #2563eb; break-after:avoid; }
p { margin:6px 0; }
blockquote { border-left:4px solid #f59e0b; background:#fffbeb; margin:10px 0; padding:8px 12px; color:#663c00; font-size:9.8pt; border-radius:3px; }
table { border-collapse:collapse; width:100%; margin:8px 0 12px; font-size:8.6pt; }
thead { display:table-header-group; }
th { background:#1e293b; color:#fff; text-align:left; padding:5px 7px; font-weight:600; vertical-align:top; }
td { border:1px solid #cbd5e1; padding:4px 7px; vertical-align:top; word-break:break-word; }
tbody tr:nth-child(even) { background:#f8fafc; }
tr { break-inside:avoid; }
ul { margin:6px 0; padding-left:20px; }
li { margin:3px 0; font-size:9.6pt; }
strong { color:#0f172a; } em { color:#475569; }
code { background:#eef2ff; color:#3730a3; padding:1px 4px; border-radius:3px; font-size:9pt; font-family:'Cascadia Code','Consolas',monospace; }
hr { border:none; border-top:2px solid #e2e8f0; margin:18px 0; }
"""


def find_browser() -> str | None:
    return next((p for p in (
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    ) if Path(p).exists()), None)


def targets(argv: list[str]) -> list[Path]:
    if argv:
        out = []
        for a in argv:
            p = OUT / (a if a.endswith(".md") else a + ".md")
            if not p.exists():
                print(f"!! not found: {p.relative_to(HERE)}")
            else:
                out.append(p)
        return out
    return sorted(p for p in OUT.glob("*.md") if p.stem not in SKIP)


def render_one(md: Path, browser: str | None) -> bool:
    html, pdf = md.with_suffix(".html"), md.with_suffix(".pdf")
    title = next((ln.lstrip("# ").strip() for ln in md.read_text(encoding="utf-8").splitlines()
                  if ln.startswith("# ")), md.stem)
    body = markdown.markdown(md.read_text(encoding="utf-8"),
                             extensions=["tables", "fenced_code", "sane_lists", "attr_list", "toc"])
    html.write_text(f'<!doctype html><html><head><meta charset="utf-8"><title>{title}</title>'
                    f"<style>{CSS}</style></head><body>{body}</body></html>", encoding="utf-8")
    if not browser:
        print(f"   wrote {html.name} (no Chrome/Edge found; open it and Ctrl-P -> Save as PDF)")
        return False
    subprocess.run([browser, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    f"--print-to-pdf={pdf}", html.as_uri()], check=False)
    print(f"   {md.name} -> {pdf.name}")
    return True


def main() -> int:
    docs = targets(sys.argv[1:])
    if not docs:
        print(f"No routine docs to render in {OUT}")
        return 1
    browser = find_browser()
    print(f"Rendering {len(docs)} routine doc(s) from {OUT.relative_to(HERE.parent)}/ :")
    ok = all(render_one(d, browser) for d in docs)
    return 0 if (ok or not browser) else 0


if __name__ == "__main__":
    sys.exit(main())
