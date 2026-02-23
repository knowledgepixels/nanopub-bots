#!/usr/bin/env bash
# Look up ORCIDs for all authors of a paper, given its DOI.
# Uses CrossRef for author order and any ORCIDs already known; searches ORCID for the rest.
# Usage: scripts/orcid-search-all.sh <doi>

set -euo pipefail

DOI="${1:?Usage: scripts/orcid-search-all.sh <doi>}"
DOI="${DOI#https://doi.org/}"

curl -sf "https://api.crossref.org/works/${DOI}" -o /tmp/orcid-search-all.json

python3 << 'EOF'
import json, subprocess

with open('/tmp/orcid-search-all.json') as f:
    d = json.load(f)['message']

print(f"Authors for {d.get('DOI', '')} (CrossRef order):")
for i, a in enumerate(d.get('author') or [], 1):
    given  = a.get('given', '')
    family = a.get('family', '')
    name   = f"{given} {family}".strip()
    cr_orcid = (a.get('ORCID') or '').replace('http://orcid.org/', 'https://orcid.org/')

    if cr_orcid.startswith('https://orcid.org/'):
        print(f"  {i}. {name:<30s}  {cr_orcid}  [CrossRef]")
        continue

    result = subprocess.run([
        'curl', '-s', '--get',
        '--data-urlencode', f'q=family-name:{family} AND given-names:{given}',
        'https://pub.orcid.org/v3.0/search/',
        '-H', 'Accept: application/json',
    ], capture_output=True, text=True)

    try:
        data   = json.loads(result.stdout)
        orcids = [f"https://orcid.org/{r['orcid-identifier']['path']}"
                  for r in data.get('result', [])
                  if (r.get('orcid-identifier') or {}).get('path')]
    except Exception:
        orcids = []

    if len(orcids) == 1:
        print(f"  {i}. {name:<30s}  {orcids[0]}  [1 match — verify]")
    elif not orcids:
        print(f"  {i}. {name:<30s}  (not found)")
    else:
        print(f"  {i}. {name:<30s}  {len(orcids)} results:")
        for o in orcids[:4]:
            print(f"       {o}")
EOF
