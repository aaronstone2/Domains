import trafilatura

from ingest.models import Document, Source


def extract(source: Source, body: bytes) -> Document:
    """Extract clean markdown from a fetched HTML body. V1 = trafilatura for everything.

    Per-parser variants (manpage, github-md, mintlify) come in later sessions; for now we use
    trafilatura's `output_format='markdown'` everywhere because it produces usable output across
    most doc sites including man7.org and Mintlify.
    """
    text = trafilatura.extract(
        body.decode("utf-8", errors="replace"),
        output_format="markdown",
        include_links=True,
        include_tables=True,
        include_images=False,
        favor_recall=True,
    )
    return Document(
        source_id=source.id,
        section_path=source.url,
        content_md=text or "",
    )
