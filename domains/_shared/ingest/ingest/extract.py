import json

import pymupdf
import trafilatura

from ingest.models import Document, Source


def _extract_html(body: bytes) -> str:
    text = trafilatura.extract(
        body.decode("utf-8", errors="replace"),
        output_format="markdown",
        include_links=True,
        include_tables=True,
        include_images=False,
        favor_recall=True,
    )
    return text or ""


def _extract_pdf(body: bytes) -> str:
    doc = pymupdf.open(stream=body, filetype="pdf")
    try:
        return "\n\n".join(page.get_text("text") for page in doc).strip()
    finally:
        doc.close()


def _extract_passthrough(body: bytes) -> str:
    return body.decode("utf-8", errors="replace").strip()


def _extract_json(body: bytes) -> str:
    parsed = json.loads(body.decode("utf-8", errors="replace"))
    return json.dumps(parsed, indent=2, ensure_ascii=False)


def extract(source: Source, body: bytes) -> Document:
    """Extract clean text from a fetched body, dispatching on source.parser.

    parser=pdf              → pymupdf text extraction (sparse on image-heavy PDFs without OCR)
    parser=github-md        → passthrough (raw markdown URLs already return our target format)
    parser=json-passthrough → pretty-printed JSON (BM25-friendly, human-readable in spot-checks)
    parser=anything-else    → trafilatura HTML→markdown
    """
    if source.parser == "pdf":
        text = _extract_pdf(body)
    elif source.parser == "github-md":
        text = _extract_passthrough(body)
    elif source.parser == "json-passthrough":
        text = _extract_json(body)
    else:
        text = _extract_html(body)
    return Document(source_id=source.id, section_path=source.url, content_md=text)
