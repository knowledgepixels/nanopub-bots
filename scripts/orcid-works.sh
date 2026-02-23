#!/usr/bin/env bash
# Show recent works for an ORCID (useful for disambiguating common names).
# Usage: scripts/orcid-works.sh <orcid>
# <orcid> can be a bare ID (0000-0002-1267-0234) or full URI.

set -euo pipefail

ORCID="${1:?Usage: scripts/orcid-works.sh <orcid>}"
ORCID="${ORCID#https://orcid.org/}"  # strip URI prefix if present

curl -s -H 'Accept: application/json' \
    "https://pub.orcid.org/v3.0/${ORCID}/works" -o /tmp/orcid-works.json

python3 << 'EOF'
import json
with open('/tmp/orcid-works.json') as f:
    data = json.load(f)
groups = data.get('group', [])
print(f"Found {len(groups)} work(s)")
for g in groups[:20]:
    summaries = g.get('work-summary', [])
    if not summaries:
        continue
    s = summaries[0]
    title = (s.get('title') or {}).get('title', {}).get('value', '(no title)')
    year = (s.get('publication-date') or {})
    year = (year.get('year') or {}).get('value', '')
    etype = s.get('type', '')
    print(f"  {year}  {title}" + (f" [{etype}]" if etype else ''))
EOF
