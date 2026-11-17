# Prints the last lines of a Docker project's logs on the VPS, with tokens redacted.
# Usage: python3 -I script/hostinger/journaux.py <project> [lines] [grep]
import json, re, sys, urllib.request

project = sys.argv[1]
count = int(sys.argv[2]) if len(sys.argv) > 2 else 40
pattern = re.compile(sys.argv[3], re.I) if len(sys.argv) > 3 else None
req = urllib.request.Request(f"https://developers.hostinger.com/api/vps/v1/virtual-machines/2172236/docker/{project}/logs",
                             headers={"User-Agent": "curl/8.5.0"})
with urllib.request.urlopen(req, timeout=60) as r:
    data = json.load(r)
# Expected: [{service, entries: [{timestamp, line}]}]. Anything else stops here rather than printing raw data.
if not isinstance(data, list) or not all(isinstance(s, dict) and isinstance(s.get("entries"), list) for s in data):
    sys.exit("réponse Hostinger inattendue : forme des journaux inconnue, rien affiché")
entries = data
lines = [f"[{s.get('service')}] {e.get('line', '')}" for s in data for e in s["entries"]]
# Tokens and credentials inside URLs (postgres://user:pass@, https://x-access-token:...@).
redact = lambda s: re.sub(r"github_pat_\S+|ghp_\S+|\w+://[^:/\s]+:[^@\s]+@", "[masqué]", s)
lines = [redact(l) for l in lines if not pattern or pattern.search(l)]
print(f"{len(entries)} entrées")
print("\n".join(l[:300] for l in lines[-count:]))
