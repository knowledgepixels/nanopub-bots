#!/usr/bin/env bash
# Verify a ROR organization: show name, aliases, country, and type.
# Usage: scripts/ror-verify.sh <ror-id>
# <ror-id> can be a bare ID (008xxew50) or full URI (https://ror.org/008xxew50).

set -euo pipefail

ROR="${1:?Usage: scripts/ror-verify.sh <ror-id>}"
ROR="${ROR#https://ror.org/}"  # strip URI prefix if present

curl -s "https://api.ror.org/v2/organizations/${ROR}" -o /tmp/ror-verify.json

python3 << 'EOF'
import json
with open('/tmp/ror-verify.json') as f:
    data = json.load(f)
ror_id = data.get('id', '')
names = data.get('names', [])
primary = next((n['value'] for n in names if 'ror_display' in n.get('types', [])), '')
aliases = [n['value'] for n in names if 'ror_display' not in n.get('types', []) and n['value'] != primary]
locations = data.get('locations', [])
country = locations[0].get('geonames_details', {}).get('country_name', '') if locations else ''
types = data.get('types', [])
print(f"ROR:     {ror_id}")
print(f"Name:    {primary}")
if aliases:
    print(f"Aliases: {', '.join(aliases[:5])}")
if country:
    print(f"Country: {country}")
if types:
    print(f"Types:   {', '.join(types)}")
EOF
