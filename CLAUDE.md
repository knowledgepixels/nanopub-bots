# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **data repository** containing nanopublications created by three specialized bots. Nanopublications are minimalist semantic publications in RDF Trig format, cryptographically signed with RSA keys.

The project creator is Tobias Kuhn (ORCID: 0000-0002-1267-0234).

## Repository Structure

Each bot has its own directory with a consistent layout:
- `examples/` — reference nanopublication showing expected structure
- `output/` — generated unsigned nanopublications
- `signed/` — cryptographically signed versions (ready for publishing)
- `README.md` — bot IRI and key file location

### Bots

| Bot | Domain | Key File |
|---|---|---|
| `doibot` | Academic papers (via DOI/Crossref) | `~/.nanopub/doibot_id_rsa` |
| `biodivbot` | Organism-environment associations (BioLink, ENVO, UBERON ontologies) | `~/.nanopub/biodivbot_id_rsa` |
| `ai-in-edu-bot` | AI approaches in education research | `~/.nanopub/ai-in-edu-bot_id_rsa` |

## Nanopublication Structure

Every nanopub (`.trig` file) contains four named graphs:
1. **Head** — links to the other three graphs
2. **Assertion** — the semantic claims (domain-specific RDF triples)
3. **Provenance** — attribution and source references
4. **PublicationInfo** — metadata, bot identity, and RSA signature (in signed versions)

The `plain.introtemplate.trig` at the repo root is a template for introducing new bots to the nanopub network.

## nanopub-java CLI

The `./np` wrapper script runs the nanopub-java CLI from the sibling `../nanopub-java` repo. If the JAR isn't built yet:

```bash
mvn -f ../nanopub-java clean package -DskipTests
```

### Key commands

```bash
./np sign <file.trig>                    # Sign a nanopub (uses ~/.nanopub/id_rsa by default)
./np sign -k ~/.nanopub/doibot_id_rsa <file.trig>   # Sign with a specific bot key
./np publish <signed.trig>               # Publish to the nanopub network
./np check <file.trig>                   # Validate a nanopub
./np retract -i <nanopub-uri-or-file>    # Create a retraction nanopub
./np retract -i <nanopub-uri> -p         # Retract and publish the retraction
```

### Superseding nanopublications

To publish an updated version of a nanopub, add an `npx:supersedes` triple in the `pubinfo` graph pointing to the old nanopub's URI:

```turtle
this:pubinfo {
  this: ...
    npx:supersedes <https://w3id.org/np/RAold...> ;
    ...
}
```

Then sign and publish the new nanopub. The old one remains immutable on the network but is marked as superseded.

For index nanopubs, `mkindex -x <old-index-uri>` adds the supersedes link automatically:

```bash
./np mkindex -x <old-index-uri> -o new-index.trig -t "Title" file1.trig file2.trig
```

## Retrieving metadata for DOI-based nanopubs

Use content negotiation to retrieve RDF directly from the DOI:

```bash
curl -sL -H 'Accept: text/turtle' 'https://doi.org/10.1007/11799511_7'
```

This returns structured RDF (Turtle) with title, authors, ORCIDs, ROR affiliations, and other metadata. The abstract (`dct:abstract`) is optional — include it when available from the metadata, but simply leave it out if not. Only perform additional web searches (CrossRef API, publisher pages, etc.) if the RDF is not returned or seems wrong/incomplete.

### Important caveats about DOI metadata

- **Author order is NOT preserved** in the RDF. Always verify author order from the actual paper/publisher page.
- **ORCIDs are often missing** from the RDF. Some publishers include `owl:sameAs` ORCID links (e.g. IEEE, some Springer papers), but many don't. Always search ORCID separately when not present.
- **CrossRef metadata can include non-authors** (e.g. guest editors). Verify the author list against the actual paper.

### Looking up and verifying ORCIDs

- **Search**: `https://pub.orcid.org/v3.0/search/?q=family-name:Last+AND+given-names:First` (Accept: application/json)
- **Verify person**: `https://pub.orcid.org/v3.0/<ORCID>/person`
- **Check employments** (for affiliations): `https://pub.orcid.org/v3.0/<ORCID>/employments`
- **Check works** (to disambiguate common names): `https://pub.orcid.org/v3.0/<ORCID>/works`
- For names with diacritics (e.g. Meroño-Peñuela), URL-encode the special characters in the search query.
- Common names may return multiple results — verify by checking works or employment history.
- Use ORCID URIs (e.g. `orcid:0000-0002-1267-0234`) instead of local identifiers whenever an ORCID is found.

### Looking up and verifying RORs

- **Search**: `https://api.ror.org/v2/organizations?query=<name>`
- **Verify**: `https://api.ror.org/v2/organizations/<ROR-ID>` (use full URL like `https://ror.org/008xxew50`)

### API usage tips

When piping `curl` to `python3`, the output can arrive empty via stdin. The reliable pattern is to save to a file first, then parse:

```bash
curl -s -H 'Accept: application/json' '<url>' -o /tmp/result.json && python3 -c "
import json
with open('/tmp/result.json') as f:
    data = json.load(f)
..."
```

## Workflow: creating/updating nanopubs

1. Edit the output file in `<bot>/output/`
2. Sign: `./np sign -k <key-file> <bot>/output/<name>.trig -o <bot>/signed/signed.<name>.trig`
3. Publish: `./np publish <bot>/signed/signed.<name>.trig`

When updating an existing nanopub:
- Update the `dct:created` timestamp to the exact current date/time (not rounded)
- Add/update `npx:supersedes` in the pubinfo graph pointing to the old signed URI
- Then re-sign and publish

### Personal information policy

Only include personal information (names, email addresses, affiliations, ORCIDs, etc.) in a nanopublication if it is already permanently and openly published — e.g. expressed in a published scientific paper or made available online by the person themselves under a permanent open license (such as CC0 or CC-BY).

### License

All bot nanopublications must be published under **CC0** (https://creativecommons.org/publicdomain/zero/1.0/), not CC-BY.

### FaBiO types for doibot

- `fabio:Article` — journal articles (with `dct:isPartOf` linking to ISSN)
- `fabio:BookChapter` — book/proceedings chapters (e.g. LNCS/Springer, with `dct:isPartOf` linking to ISSN)
- `fabio:ConferencePaper` — standalone conference papers without a journal ISSN (e.g. ACM, IEEE proceedings); `dct:isPartOf` can be omitted

All doibot nanopubs use `npx:hasNanopubType fabio:ScholarlyWork` in pubinfo regardless of the specific FaBiO type.

### Checking existing doibot nanopubs

To see which papers already have nanopubs for a given author:

```
https://nanodash.knowledgepixels.com/query?runquery=RA7X8hbsozQjZCv4RfWGIgzEA6qr9Ds6RL5kQnB7GHThc/get-papers-for-author&queryparam_author=https://orcid.org/0000-0002-1267-0234
```

### Provenance patterns per bot

- **doibot**: `prov:wasAttributedTo` (paper authors) + `prov:wasDerivedFrom` (paper DOI)
- **biodivbot**: `prov:wasAttributedTo` (researchers who made the observation)
- **ai-in-edu-bot**: `prov:wasDerivedFrom` (paper DOI)

### Temp URI prefix

Output files **must** use `@prefix : <http://purl.org/nanopub/temp/np1/> .` as the base prefix. This is the standard nanopub temp URI that gets replaced with a proper trusty URI (`https://w3id.org/np/RA...`) during signing. Using `<https://w3id.org/np/temp>` instead causes the signed URI to incorrectly contain `/temp/`.

## External Dependencies

- **Nanopub network**: Published via nanodash.knowledgepixels.com / nanodash.petapico.org
- **Identifiers**: ORCID, ROR, CrossRef DOIs, ChecklistBank, PubMed
- **Ontologies**: ENVO (environments), UBERON (anatomy/life stages), BioLink (associations), Schema.org, Dublin Core, PROV
