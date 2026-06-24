import hashlib
from datetime import datetime, timezone
from pathlib import Path

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from ingest.models import Source

# Browser-like UA + Accept headers. Many journal/blog hosts (T&F, PeerJ, university OERs,
# practitioner blogs) 403 a non-browser client; a standard desktop UA fetches the same public pages.
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
)

_HEADERS = {
    "User-Agent": USER_AGENT,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}


@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
def _get(url: str) -> bytes:
    with httpx.Client(
        headers=_HEADERS,
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
