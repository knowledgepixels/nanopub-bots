#!/usr/bin/env bash
# Generate a draft doibot nanopub .trig file from a DOI.
# Fetches metadata from CrossRef and auto-searches ORCID for each author.
# Output: doibot/output/<doi-as-filename>.trig
# Usage: scripts/doi-to-trig.sh <doi>

set -euo pipefail

DOI="${1:?Usage: scripts/doi-to-trig.sh <doi>}"
DOI="${DOI#https://doi.org/}"

FILENAME="${DOI//\//_}"
OUTFILE="doibot/output/${FILENAME}.trig"

if [[ -f "$OUTFILE" ]]; then
    echo "Error: $OUTFILE already exists. Delete it first to regenerate." >&2
    exit 1
fi

echo "Fetching CrossRef metadata for ${DOI}..." >&2
curl -sf "https://api.crossref.org/works/${DOI}" -o /tmp/doi-to-trig-cr.json

export NP_DOI="$DOI"
export NP_FILENAME="$FILENAME"
export NP_OUTFILE="$OUTFILE"
export NP_TIMESTAMP
NP_TIMESTAMP="$(scripts/timestamp.sh)"

python3 << 'PYEOF'
import json, re, html, subprocess, os, sys

DOI       = os.environ['NP_DOI']
FILENAME  = os.environ['NP_FILENAME']
OUTFILE   = os.environ['NP_OUTFILE']
TIMESTAMP = os.environ['NP_TIMESTAMP']
BOT_IRI   = 'https://w3id.org/np/RAkkUz7qBJ-BIOCHV_4WCTgHCdTyI25_bnRuw166SXjwM/DOI-bot'

# ── helpers ──────────────────────────────────────────────────────────────────

def strip_markup(text):
    text = re.sub(r'<[^>]+>', ' ', text or '')
    return html.unescape(re.sub(r'\s+', ' ', text).strip())

def esc(s):
    """Escape a value for use inside a Turtle double-quoted string."""
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ').replace('\r', '')

def make_id(given, family):
    name = f"{given.lower()}-{family.lower()}"
    return re.sub(r'[^a-z0-9]+', '-', name).strip('-')

def short_orcid(uri):
    return uri.replace('https://orcid.org/', '')

# ── parse CrossRef ────────────────────────────────────────────────────────────

with open('/tmp/doi-to-trig-cr.json') as f:
    msg = json.load(f)

if 'message' not in msg:
    print("Error: DOI not found in CrossRef", file=sys.stderr)
    sys.exit(1)

d = msg['message']

title       = esc(strip_markup((d.get('title') or [''])[0]))
cr_type     = d.get('type', '')
date_parts  = (d.get('published') or {}).get('date-parts', [[]])[0]
date_str    = '-'.join(str(x).zfill(2) for x in date_parts) if date_parts else ''
pages       = d.get('page', '') or ''
containers  = d.get('container-title') or []
container   = esc(containers[0]) if containers else ''
issns       = d.get('ISSN') or []
issn        = issns[0] if issns else ''
event_name  = esc((d.get('event') or {}).get('name', ''))
abstract    = esc(strip_markup(d.get('abstract', '') or ''))

# Parse pages: handles "241-248", "e001-e015", "S1-S15"
page_start = page_end = ''
page_match = re.match(r'^(\S+?)\s*-\s*(\S+)$', pages)
if page_match:
    page_start, page_end = page_match.group(1), page_match.group(2)
elif pages:
    page_start = pages

# fabio type
type_map = {
    'journal-article':    'fabio:Article',
    'book-chapter':       'fabio:BookChapter',
    'proceedings-article': 'fabio:ConferencePaper',
}
fabio_type = type_map.get(cr_type, 'fabio:Article')

# ── resolve ORCIDs ────────────────────────────────────────────────────────────

authors_raw = d.get('author') or []
print(f"Resolving ORCIDs for {len(authors_raw)} authors...", file=sys.stderr)

authors = []
for a in authors_raw:
    given  = a.get('given', '')
    family = a.get('family', '')
    entry  = {
        'given':      given,
        'family':     family,
        'name':       f"{given} {family}".strip(),
        'blank_id':   make_id(given, family),
        'orcid':      None,
        'status':     None,
        'candidates': [],
    }
    cr_orcid = (a.get('ORCID') or '').replace('http://orcid.org/', 'https://orcid.org/')
    if cr_orcid.startswith('https://orcid.org/'):
        entry['orcid']  = cr_orcid
        entry['status'] = 'crossref'
    else:
        print(f"  Searching ORCID for {entry['name']}...", file=sys.stderr)
        result = subprocess.run([
            'curl', '-s', '--get',
            '--data-urlencode', f"q=family-name:{family} AND given-names:{given}",
            'https://pub.orcid.org/v3.0/search/',
            '-H', 'Accept: application/json',
        ], capture_output=True, text=True)
        try:
            data   = json.loads(result.stdout)
            cands  = [f"https://orcid.org/{r['orcid-identifier']['path']}"
                      for r in data.get('result', [])
                      if (r.get('orcid-identifier') or {}).get('path')]
        except Exception:
            cands = []
        entry['candidates'] = cands
        if len(cands) == 1:
            entry['orcid']  = cands[0]
            entry['status'] = 'found'
        elif not cands:
            entry['status'] = 'notfound'
        else:
            entry['status'] = 'multiple'
    authors.append(entry)

def author_ref(a):
    return f"orcid:{short_orcid(a['orcid'])}" if a['orcid'] else f":{a['blank_id']}"

def author_comment(a):
    if a['status'] == 'crossref':  return ''
    if a['status'] == 'found':     return '  # VERIFY (auto-found, 1 ORCID match)'
    if a['status'] == 'notfound':  return '  # TODO: ORCID not found'
    cands_str = ', '.join(a['candidates'][:3])
    return f"  # TODO: {len(a['candidates'])} ORCID matches — {cands_str}"

# ── build Trig ────────────────────────────────────────────────────────────────

L = []

L += [
    '@prefix : <http://purl.org/nanopub/temp/np1/> .',
    '@prefix np: <http://www.nanopub.org/nschema#> .',
    '@prefix dct: <http://purl.org/dc/terms/> .',
    '@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .',
    '@prefix nt: <https://w3id.org/np/o/ntemplate/> .',
    '@prefix npx: <http://purl.org/nanopub/x/> .',
    '@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .',
    '@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .',
    '@prefix orcid: <https://orcid.org/> .',
    '@prefix ns1: <http://purl.org/np/> .',
    '@prefix prov: <http://www.w3.org/ns/prov#> .',
    '@prefix foaf: <http://xmlns.com/foaf/0.1/> .',
    '@prefix bibo: <http://purl.org/ontology/bibo/> .',
    '@prefix fabio: <http://purl.org/spar/fabio/> .',
    '@prefix ror: <https://ror.org/> .',
    '@prefix schema: <http://schema.org/> .',
    '',
    ':Head {',
    '  : a np:Nanopublication;',
    '    np:hasAssertion :assertion;',
    '    np:hasProvenance :provenance;',
    '    np:hasPublicationInfo :pubinfo .',
    '}',
    '',
    ':assertion {',
]

# Paper properties
paper_uri = f'<https://doi.org/{DOI}>'
props = [f'a {fabio_type}']
if abstract:    props.append(f'dct:abstract "{abstract}"')
props.append(f'dct:date "{date_str}"')
props.append(f'dct:title "{title}"')
props.append('bibo:authorList :author-list')
if page_start:  props.append(f'bibo:pageStart "{page_start}"')
if page_end:    props.append(f'bibo:pageEnd "{page_end}"')
if issn:
    props.append(f'dct:isPartOf <http://id.crossref.org/issn/{issn}>')
elif container or event_name:
    props.append('dct:isPartOf :proceedings')

L.append(f'  {paper_uri} {props[0]};')
for p in props[1:-1]:
    L.append(f'    {p};')
L.append(f'    {props[-1]} .')
L.append('')

# Journal / proceedings reference
if issn and container:
    L.append(f'  <http://id.crossref.org/issn/{issn}> dct:title "{container}" .')
    L.append('')
elif container or event_name:
    venue = container or event_name
    L.append(f'  :proceedings dct:title "{venue}" .')
    L.append('')

# Author list
for i, a in enumerate(authors, 1):
    L.append(f'  :author-list rdf:_{i} {author_ref(a)} .{author_comment(a)}')
L.append('')

# Author details
for a in authors:
    L.append(f'  {author_ref(a)} foaf:name "{esc(a["name"])}" .')

L += ['}', '']

# Provenance
orcid_authors = [a for a in authors if a['orcid']]
L.append(':provenance {')
if orcid_authors:
    attrs = ', '.join(f"orcid:{short_orcid(a['orcid'])}" for a in orcid_authors)
    L.append(f'  :assertion prov:wasAttributedTo {attrs} .')
L.append(f'  :assertion prov:wasDerivedFrom <https://doi.org/{DOI}> .')
L += ['}', '']

# Pubinfo
L += [
    ':pubinfo {',
    f'  : dct:created "{TIMESTAMP}"^^xsd:dateTime;',
    f'    dct:creator <{BOT_IRI}>;',
    f'    dct:license <https://creativecommons.org/publicdomain/zero/1.0/>;',
    f'    npx:hasNanopubType fabio:ScholarlyWork;',
    f'    npx:introduces <https://doi.org/{DOI}>;',
    f'    rdfs:label "{title}" .',
    '',
]
for a in orcid_authors:
    L.append(f'  orcid:{short_orcid(a["orcid"])} foaf:name "{esc(a["name"])}" .')
L += [
    '',
    f'  :sig npx:signedBy <{BOT_IRI}> .',
    '}',
]

with open(OUTFILE, 'w') as f:
    f.write('\n'.join(L) + '\n')

# ── summary ───────────────────────────────────────────────────────────────────

print(f"\nDraft written: {OUTFILE}")
print(f"Title: {title}")
print(f"Type:  {fabio_type}  ({cr_type})")
print(f"Date:  {date_str}")
if issn:         print(f"ISSN:  {issn}  ({container})")
elif container:  print(f"Venue: {container}")

print(f"\nAuthors:")
status_labels = {
    'crossref': '[CrossRef]',
    'found':    '[auto-found — VERIFY]',
    'notfound': '[TODO: not found]',
}
for i, a in enumerate(authors, 1):
    tag = status_labels.get(a['status']) or f"[TODO: {len(a['candidates'])} ORCID matches]"
    print(f"  {i}. {a['name']:<28s}  {author_ref(a):<45s}  {tag}")
    if a['status'] == 'multiple':
        for c in a['candidates'][:4]:
            print(f"       {c}")

needs_attention = [a for a in authors if a['status'] != 'crossref']
if needs_attention:
    print(f"\nReminders:")
    print(f"  - Check author order against the publisher page (CrossRef order may be wrong)")
    print(f"  - Verify ORCIDs marked [auto-found] with: scripts/orcid-verify.sh <orcid>")
    print(f"  - Add schema:affiliation ror:... to author entries if known")
print(f"\nNext: scripts/sign-publish.sh doibot {FILENAME}")
PYEOF
