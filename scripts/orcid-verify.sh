#!/usr/bin/env bash
# Verify an ORCID: show name and employment history.
# Usage: scripts/orcid-verify.sh <orcid>
# <orcid> can be a bare ID (0000-0002-1267-0234) or full URI.

set -euo pipefail

ORCID="${1:?Usage: scripts/orcid-verify.sh <orcid>}"
ORCID="${ORCID#https://orcid.org/}"  # strip URI prefix if present

curl -s -H 'Accept: application/json' \
    "https://pub.orcid.org/v3.0/${ORCID}/person" -o /tmp/orcid-person.json
curl -s -H 'Accept: application/json' \
    "https://pub.orcid.org/v3.0/${ORCID}/employments" -o /tmp/orcid-employments.json

python3 << 'EOF'
import json
with open('/tmp/orcid-person.json') as f:
    person = json.load(f)
with open('/tmp/orcid-employments.json') as f:
    emp = json.load(f)

name = person.get('name', {})
given = (name.get('given-names') or {}).get('value', '')
family = (name.get('family-name') or {}).get('value', '')
print(f"Name: {given} {family}")

groups = emp.get('affiliation-group', [])
if groups:
    print("Employments:")
    for g in groups[:5]:
        for s in g.get('summaries', []):
            es = s.get('employment-summary', {})
            org = es.get('organization', {}).get('name', '')
            role = es.get('role-title') or ''
            start = (es.get('start-date') or {})
            year = (start.get('year') or {}).get('value', '')
            end = es.get('end-date')
            period = f"{year}–{'present' if not end else ''}" if year else ''
            print(f"  {org}" + (f" | {role}" if role else '') + (f" ({period})" if period else ''))
else:
    print("No employments found.")
EOF
