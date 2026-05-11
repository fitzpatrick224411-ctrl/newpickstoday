#!/usr/bin/env python3
"""
SecurePicksToday — Free Traffic Promoter
Runs after each article publish. Submits to free channels:
  1. IndexNow (instant Bing/Yandex indexing)
  2. Google Search Console ping
  3. Pings sitemap to multiple search engines
  4. Posts to relevant Reddit communities (r/privacy, r/netsec, r/vpn etc.)

Usage: python3 promote.py [--url <full_url>] [--title <title>]
       (if no args, promotes the latest post)
"""
import os, sys, json, time, re, subprocess
import urllib.request, urllib.parse
from pathlib import Path
from datetime import datetime

SITE_DIR  = Path(__file__).parent
SITE_BASE = "https://fitzpatrick224411-ctrl.github.io/newpickstoday"
LOG_FILE  = SITE_DIR / "promote.log"
STATE_FILE = SITE_DIR / ".promote_state.json"

# IndexNow key (free — submit to Bing/Yandex instantly)
INDEXNOW_KEY = "securepickstoday2026"

def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass

def load_state():
    if STATE_FILE.exists():
        try: return json.loads(STATE_FILE.read_text())
        except: pass
    return {"promoted": []}

def save_state(s):
    STATE_FILE.write_text(json.dumps(s, indent=2))

def get_latest_post_url():
    """Return (url, title) of the most recently published post."""
    posts = sorted(SITE_DIR.glob("_posts/*.md"), reverse=True)
    if not posts:
        return None, None
    f = posts[0]
    content = f.read_text()
    title_m = re.search(r'^title:\s*["\']?(.*?)["\']?\s*$', content, re.MULTILINE)
    title = title_m.group(1).strip('"\'') if title_m else f.stem
    m = re.match(r'(\d{4})-(\d{2})-(\d{2})-(.*)', f.stem)
    if m:
        y, mo, d, slug = m.groups()
        url = f"{SITE_BASE}/{y}/{mo}/{d}/{slug}/"
    else:
        url = SITE_BASE
    return url, title

def ping_indexnow(url):
    """Submit URL to IndexNow (free instant Bing/Yandex indexing)."""
    try:
        payload = json.dumps({
            "host": "fitzpatrick224411-ctrl.github.io",
            "key": INDEXNOW_KEY,
            "urlList": [url]
        }).encode()
        req = urllib.request.Request(
            "https://api.indexnow.org/indexnow",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            log(f"IndexNow ping: HTTP {r.status} — {url}")
    except Exception as e:
        log(f"IndexNow error: {e}")

def ping_search_engines(sitemap_url):
    """Ping multiple search engines with the sitemap."""
    engines = [
        f"https://www.bing.com/ping?sitemap={urllib.parse.quote(sitemap_url)}",
        f"https://www.google.com/ping?sitemap={urllib.parse.quote(sitemap_url)}",
    ]
    for engine_url in engines:
        try:
            req = urllib.request.Request(engine_url, method="GET")
            with urllib.request.urlopen(req, timeout=10) as r:
                log(f"Sitemap ping {engine_url[:50]}...: HTTP {r.status}")
        except Exception as e:
            log(f"Sitemap ping error ({engine_url[:40]}): {e}")

def get_reddit_subreddits(title):
    """Pick relevant subreddits based on article topic."""
    title_lower = title.lower()
    subs = []
    if "vpn" in title_lower:
        subs += ["vpn", "privacytoolsIO", "privacy"]
    if "password" in title_lower:
        subs += ["cybersecurity", "privacy", "netsec"]
    if "antivirus" in title_lower or "malware" in title_lower:
        subs += ["antivirus", "cybersecurity", "techsupport"]
    if "browser" in title_lower or "privacy" in title_lower:
        subs += ["privacy", "privacytoolsIO"]
    if "identity" in title_lower or "dark web" in title_lower:
        subs += ["cybersecurity", "privacy"]
    if not subs:
        subs = ["cybersecurity", "privacy"]
    # Deduplicate while preserving order
    seen = set()
    return [s for s in subs if not (s in seen or seen.add(s))][:3]

def post_to_reddit_manual(url, title):
    """
    Reddit free API — no auth needed for link submission hints.
    We log the exact Reddit submission URLs so you can post them with one click.
    Reddit requires manual posting from a real account; this generates the pre-filled links.
    """
    subs = get_reddit_subreddits(title)
    log(f"--- REDDIT MANUAL POST LINKS (copy & open in browser) ---")
    for sub in subs:
        encoded_url   = urllib.parse.quote(url)
        encoded_title = urllib.parse.quote(title)
        submit_link = f"https://www.reddit.com/r/{sub}/submit?type=link&url={encoded_url}&title={encoded_title}"
        log(f"r/{sub}: {submit_link}")
    log("----------------------------------------------------------")

def post_to_quora_hint(url, title):
    """Generate Quora space submission hint."""
    log(f"--- QUORA SHARE (paste answer with link) ---")
    log(f"Search Quora for questions about: {title}")
    log(f"Link to share: {url}")
    log("--------------------------------------------")

def run_promotion(url=None, title=None):
    state = load_state()

    if not url:
        url, title = get_latest_post_url()
    if not url:
        log("ERROR: No posts found to promote.")
        return

    if url in state.get("promoted", []):
        log(f"Already promoted: {url} — skipping")
        return

    log(f"Promoting: {title}")
    log(f"URL: {url}")

    # 1. IndexNow
    ping_indexnow(url)
    time.sleep(1)

    # 2. Sitemap pings
    sitemap = f"{SITE_BASE}/sitemap.xml"
    ping_search_engines(sitemap)
    time.sleep(1)

    # 3. Reddit manual submission links
    post_to_reddit_manual(url, title)

    # 4. Quora hint
    post_to_quora_hint(url, title)

    # Mark as promoted
    state.setdefault("promoted", []).append(url)
    save_state(state)
    log(f"Promotion complete for: {title}")

if __name__ == "__main__":
    url = None
    title = None
    if "--url" in sys.argv:
        idx = sys.argv.index("--url")
        url = sys.argv[idx + 1]
    if "--title" in sys.argv:
        idx = sys.argv.index("--title")
        title = sys.argv[idx + 1]

    # If called with --all, promote every post not yet promoted
    if "--all" in sys.argv:
        posts = sorted(Path(SITE_DIR / "_posts").glob("*.md"), reverse=True)
        for f in posts:
            content = f.read_text()
            title_m = re.search(r'^title:\s*["\']?(.*?)["\']?\s*$', content, re.MULTILINE)
            t = title_m.group(1).strip('"\'') if title_m else f.stem
            m = re.match(r'(\d{4})-(\d{2})-(\d{2})-(.*)', f.stem)
            if m:
                y, mo, d, slug = m.groups()
                u = f"{SITE_BASE}/{y}/{mo}/{d}/{slug}/"
            else:
                continue
            run_promotion(u, t)
            time.sleep(2)
    else:
        run_promotion(url, title)
