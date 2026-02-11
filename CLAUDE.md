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
curl -L -H 'Accept: text/turtle' 'https://doi.org/10.1007/11799511_7'
```

This returns structured RDF (Turtle) with title, authors, ORCIDs, ROR affiliations, and other metadata. The abstract (`dct:abstract`) is optional — include it when available from the metadata, but simply leave it out if not. Only perform additional web searches (CrossRef API, publisher pages, etc.) if the RDF is not returned or seems wrong/incomplete.

Always look up and verify author ORCIDs and organization RORs:

- **ORCIDs**: Search at `https://pub.orcid.org/v3.0/search/?q=family-name:Last+AND+given-names:First` (Accept: application/json). Verify by fetching the person record at `https://pub.orcid.org/v3.0/<ORCID>/person`. Use ORCID URIs (e.g. `orcid:0000-0002-1267-0234`) instead of local identifiers whenever an ORCID is found.
- **RORs**: Verify organization identifiers at `https://api.ror.org/v2/organizations/<ROR-ID>`.

## Workflow: creating/updating nanopubs

1. Edit the output file in `<bot>/output/`
2. Sign: `./np sign -k <key-file> <bot>/output/<name>.trig -o <bot>/signed/signed.<name>.trig`
3. Publish: `./np publish <bot>/signed/signed.<name>.trig`

When updating an existing nanopub:
- Update the `dct:created` timestamp to the exact current date/time (not rounded)
- Add/update `npx:supersedes` in the pubinfo graph pointing to the old signed URI
- Then re-sign and publish

### Personal information policy

Only include personal information (names, email addresses, affiliations, ORCIDs, etc.) in a nanopublication if it is already permanently and openly published — e.g. expressed in a published scientific paper or made available online by the person themselves under a permanent open license (such as CC-BY).

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
