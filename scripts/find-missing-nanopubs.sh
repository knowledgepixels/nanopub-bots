#!/usr/bin/env bash
# List papers by an author (from their ORCID works) that don't yet have a doibot nanopub.
# Usage: scripts/find-missing-nanopubs.sh <orcid>

set -euo pipefail

ORCID="${1:?Usage: scripts/find-missing-nanopubs.sh <orcid>}"
ORCID="${ORCID#https://orcid.org/}"

curl -s -H 'Accept: application/json' \
    "https://pub.orcid.org/v3.0/${ORCID}/works" -o /tmp/find-missing.json

python3 << 'EOF'
import json, os, glob

with open('/tmp/find-missing.json') as f:
    data = json.load(f)

# Existing output files, normalised to lowercase for comparison
existing = {os.path.basename(f).replace('.trig', '').lower()
            for f in glob.glob('doibot/output/*.trig')}

groups = data.get('group', [])
missing = []

for g in groups:
    s      = g.get('work-summary', [{}])[0]
    title  = ((s.get('title') or {}).get('title') or {}).get('value', '')
    year   = (((s.get('publication-date') or {}).get('year')) or {}).get('value', '')
    wtype  = s.get('type', '')
    ids    = (s.get('external-ids') or {}).get('external-id', [])
    doi    = next((i['external-id-value'] for i in ids
                   if i.get('external-id-type') == 'doi'), '')
    if not doi:
        continue
    if doi.lower().replace('/', '_') not in existing:
        missing.append((year or '0000', doi, title, wtype))

missing.sort(key=lambda x: x[0], reverse=True)
print(f"{len(missing)} papers with DOIs not yet in doibot/output/:")
for year, doi, title, wtype in missing:
    type_tag = f"  [{wtype}]" if wtype else ""
    print(f"  {year}  {doi:45s}  {title[:55]}{type_tag}")
EOF
