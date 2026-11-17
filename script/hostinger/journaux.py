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
entries = data if isinstance(data, list) else data.get("data") or data.get("logs") or []
lines = []
for entry in entries:
    if isinstance(entry, dict) and "entries" in entry:
        lines += [f"[{entry.get('service')}] {e.get('line', '')}" for e in entry["entries"]]
    elif isinstance(entry, dict):
        lines.append(f"[{entry.get('service', '?')}] {entry.get('line') or entry.get('message') or json.dumps(entry)}")
    else:
        lines.append(str(entry))
redact = lambda s: re.sub(r"github_pat_\S+|ghp_\S+|x-access-token:[^@\s]+@", "[masqué]", s)
lines = [redact(l) for l in lines if not pattern or pattern.search(l)]
print(f"{len(entries)} entrées")
print("\n".join(l[:300] for l in lines[-count:]))
