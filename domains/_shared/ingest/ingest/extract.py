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


def extract(source: Source, body: bytes) -> Document:
    """Extract clean text from a fetched body, dispatching on source.parser.

    parser=pdf       → pymupdf text extraction (sparse on image-heavy PDFs without OCR)
    parser=github-md → passthrough (raw markdown URLs already return our target format)
    parser=anything-else → trafilatura HTML→markdown
    """
    if source.parser == "pdf":
        text = _extract_pdf(body)
    elif source.parser == "github-md":
        text = _extract_passthrough(body)
    else:
        text = _extract_html(body)
    return Document(source_id=source.id, section_path=source.url, content_md=text)
