#!/usr/bin/env bash
# Search for a ROR organization ID by name.
# Usage: scripts/ror-search.sh <organization name>
# Tip: quote multi-word names, e.g.: scripts/ror-search.sh "Vrije Universiteit Amsterdam"

set -euo pipefail

QUERY="${*:?Usage: scripts/ror-search.sh <organization name>}"

curl -s --get \
    --data-urlencode "query=${QUERY}" \
    'https://api.ror.org/v2/organizations' \
    -o /tmp/ror-search.json

python3 << 'EOF'
import json
with open('/tmp/ror-search.json') as f:
    data = json.load(f)
items = data.get('items', [])
print(f"Found {len(items)} result(s)")
for item in items[:8]:
    ror_id = item.get('id', '')
    names = item.get('names', [])
    name = names[0].get('value', '') if names else ''
    locations = item.get('locations', [])
    country = locations[0].get('geonames_details', {}).get('country_name', '') if locations else ''
    print(f"  {ror_id}  {name}" + (f"  ({country})" if country else ''))
EOF
