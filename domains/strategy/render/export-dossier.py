# -*- coding: utf-8 -*-
# Combine the rendered strategy artifacts into one dossier (md + HTML + PDF) via markdown + pymupdf Story
# (the same md->HTML->PDF path that produced market/.../paper.pdf). Run with the ingest venv.
import os, io, sys, glob
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
os.chdir(r"C:\Users\adsto\git\domains")
import markdown, pymupdf

RENDER = "domains/strategy/render"
ORDER = ["investor-deck.md", "strategy-memo.md", "battlecard-neo4j.md", "board-update.md"]

parts = ["# MetroGraph — Strategy Dossier\n",
         "_A non-divergent family of artifacts auto-projected from the cross-domain Strategy OS corpus "
         "(`ingest render`). Every figure resolves to one claim_id/source_id and carries its evidence "
         "glyph; nothing is upgraded past its honest ceiling. Generated 2026-06-26._\n",
         "\n---\n"]
for f in ORDER:
    p = os.path.join(RENDER, f)
    if os.path.exists(p):
        parts.append(open(p, encoding='utf-8').read())
        parts.append("\n\n---\n\n")
md_text = "\n".join(parts)
open(os.path.join(RENDER, "strategy-dossier.md"), "w", encoding="utf-8", newline="\n").write(md_text)

html_body = markdown.markdown(md_text, extensions=["tables", "fenced_code", "toc"])
CSS = """
body{font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;font-size:10pt;line-height:1.45;color:#1a1a1a;}
h1{font-size:20pt;border-bottom:3px solid #2a4d8f;padding-bottom:4px;color:#1b2a4a;}
h2{font-size:14pt;color:#2a4d8f;margin-top:18px;border-bottom:1px solid #ccd;}
h3{font-size:11pt;color:#3a3a3a;}
table{border-collapse:collapse;width:100%;font-size:8.5pt;margin:8px 0;}
th,td{border:1px solid #bbb;padding:3px 6px;text-align:left;vertical-align:top;}
th{background:#eef2fa;}
blockquote{color:#555;border-left:3px solid #2a4d8f;margin:8px 0;padding:4px 12px;background:#f7f9fc;font-size:9pt;}
code{background:#eef;padding:0 3px;border-radius:3px;font-size:8pt;}
hr{border:none;border-top:1px solid #ccd;margin:14px 0;}
"""
html_doc = f"<html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{html_body}</body></html>"
open(os.path.join(RENDER, "strategy-dossier.html"), "w", encoding="utf-8").write(html_doc)

# HTML -> PDF via pymupdf Story (handles flowing content + page breaks)
out = os.path.join(RENDER, "strategy-dossier.pdf")
story = pymupdf.Story(html=html_doc)
writer = pymupdf.DocumentWriter(out)
MED = pymupdf.paper_rect("letter")
AREA = MED + (36, 36, -36, -36)  # 0.5in margins
more = 1
while more:
    dev = writer.begin_page(MED)
    more, _ = story.place(AREA)
    story.draw(dev)
    writer.end_page()
writer.close()

pages = pymupdf.open(out).page_count
print(f"dossier: {len(md_text)} chars md -> {pages}-page PDF at {out}")
