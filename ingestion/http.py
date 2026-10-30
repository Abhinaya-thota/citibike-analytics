"""HTTP session with retries, plus a streaming downloader."""

from pathlib import Path

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


def session() -> requests.Session:
    retry = Retry(
        total=5,
        backoff_factor=2,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET"],
    )
    s = requests.Session()
    s.mount("https://", HTTPAdapter(max_retries=retry))
    s.headers["User-Agent"] = "citibike-analytics/1.0 (portfolio project)"
    return s


def download(url: str, dest: Path, chunk_size: int = 1 << 20) -> Path:
    """Stream url to dest, writing to a .part file so a crash never leaves a
    truncated file that looks complete."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    with session().get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(chunk_size):
                f.write(chunk)
    tmp.replace(dest)
    return dest
