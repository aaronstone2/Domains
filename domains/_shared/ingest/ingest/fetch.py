import hashlib
from datetime import datetime, timezone
from pathlib import Path

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from ingest.models import Source

USER_AGENT = (
    "domains-corpus-fetcher/0.1 "
    "(personal interview-prep knowledge corpus; contact: aaron@bubble.graphics)"
)


@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
def _get(url: str) -> bytes:
    with httpx.Client(
        headers={"User-Agent": USER_AGENT, "Accept": "*/*"},
        follow_redirects=True,
        timeout=30.0,
    ) as client:
        r = client.get(url)
        r.raise_for_status()
        return r.content


def fetch(source: Source, raw_dir: Path) -> tuple[bytes, str, datetime]:
    """Fetch `source.url`, write raw bytes to `raw_dir/<id>.html`, return (body, sha256, fetched_at)."""
    body = _get(source.url)
    digest = hashlib.sha256(body).hexdigest()
    raw_dir.mkdir(parents=True, exist_ok=True)
    cache_path = raw_dir / f"{source.id}.html"
    cache_path.write_bytes(body)
    return body, digest, datetime.now(timezone.utc)
