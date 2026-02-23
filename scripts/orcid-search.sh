#!/usr/bin/env bash
# Search for an ORCID by name.
# Usage: scripts/orcid-search.sh <family-name> <given-name>
# Handles names with diacritics (URL-encoded automatically).

set -euo pipefail

FAMILY="${1:?Usage: scripts/orcid-search.sh <family-name> <given-name>}"
GIVEN="${2:?Usage: scripts/orcid-search.sh <family-name> <given-name>}"

curl -s --get \
    --data-urlencode "q=family-name:${FAMILY} AND given-names:${GIVEN}" \
    'https://pub.orcid.org/v3.0/search/' \
    -H 'Accept: application/json' \
    -o /tmp/orcid-search.json

python3 << 'EOF'
import json
with open('/tmp/orcid-search.json') as f:
    data = json.load(f)
results = data.get('result', [])
print(f"Found {len(results)} result(s)")
for r in results:
    orcid = r.get('orcid-identifier', {}).get('path', '')
    print(f"  https://orcid.org/{orcid}")
EOF
