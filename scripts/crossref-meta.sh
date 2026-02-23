#!/usr/bin/env bash
# Show formatted CrossRef metadata for a DOI: title, type, author order, ISSN, etc.
# Usage: scripts/crossref-meta.sh <doi>

set -euo pipefail

DOI="${1:?Usage: scripts/crossref-meta.sh <doi>}"
DOI="${DOI#https://doi.org/}"

curl -sf "https://api.crossref.org/works/${DOI}" -o /tmp/crossref-meta.json

python3 << 'EOF'
import json, re, html

with open('/tmp/crossref-meta.json') as f:
    msg = json.load(f)

if 'message' not in msg:
    print("DOI not found in CrossRef")
    exit(1)

d = msg['message']
title = (d.get('title') or [''])[0]
cr_type = d.get('type', '')
date_parts = (d.get('published') or {}).get('date-parts', [[]])[0]
date_str = '-'.join(str(x).zfill(2) for x in date_parts)
pages = d.get('page', '') or ''
containers = d.get('container-title') or []
container = containers[0] if containers else ''
issns = d.get('ISSN') or []
issn = issns[0] if issns else ''
event_name = (d.get('event') or {}).get('name', '')
abstract_raw = d.get('abstract', '') or ''
abstract = re.sub(r'<[^>]+>', ' ', abstract_raw)
abstract = html.unescape(re.sub(r'\s+', ' ', abstract).strip())

print(f"Title:    {title}")
print(f"Type:     {cr_type}")
print(f"Date:     {date_str}")
if pages:       print(f"Pages:    {pages}")
if container:   print(f"Journal:  {container}")
if issn:        print(f"ISSN:     {issn}")
if event_name:  print(f"Event:    {event_name}")
if abstract:
    snippet = abstract[:300] + ('...' if len(abstract) > 300 else '')
    print(f"Abstract: {snippet}")

authors = d.get('author') or []
print(f"\nAuthors ({len(authors)} total, CrossRef order):")
for i, a in enumerate(authors, 1):
    name = f"{a.get('given', '')} {a.get('family', '')}".strip()
    orcid = (a.get('ORCID') or '').replace('http://orcid.org/', 'https://orcid.org/')
    orcid_str = f"  [{orcid}]" if orcid else ""
    affs = [af.get('name', '') for af in (a.get('affiliation') or []) if af.get('name')]
    aff_str = f"  ({'; '.join(affs[:2])})" if affs else ""
    print(f"  {i}. {name}{orcid_str}{aff_str}")
EOF
