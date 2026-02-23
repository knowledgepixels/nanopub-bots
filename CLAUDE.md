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

Raw CLI reference (use the scripts below for common operations):

```bash
./np sign -k <key> <file.trig> -o <out.trig>  # sign with specific key
./np publish <signed.trig>                     # publish to nanopub network
./np check <file.trig>                         # validate a nanopub
./np retract -i <nanopub-uri-or-file>          # create a retraction nanopub
./np retract -i <nanopub-uri> -p               # retract and publish
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

## Scripts

The `scripts/` directory contains helpers for common tasks. All scripts take `<name>` as the file basename without the `.trig` extension.

### Signing and publishing

```bash
scripts/sign.sh <bot> <name>          # sign output/<name>.trig → signed/signed.<name>.trig
scripts/publish.sh <bot> <name>       # publish signed/signed.<name>.trig
scripts/sign-publish.sh <bot> <name>  # sign + publish in one step
scripts/check.sh <bot> <name>         # validate output/<name>.trig
```

### Timestamps

```bash
scripts/timestamp.sh   # prints e.g. 2026-02-23T14:05:31.000+01:00
```

Always use local time (not UTC). Do **not** use `date -u`.

### DOI metadata

```bash
scripts/doi-meta.sh 10.1007/11799511_7
```

Returns Turtle RDF with title, authors, ORCIDs, ROR affiliations, etc. The abstract (`dct:abstract`) is optional — include it when available, omit it when not. Only use CrossRef API or publisher pages if the RDF is missing or wrong.

**Caveats:**
- **Author order is NOT preserved** in the RDF. Always verify from the actual paper/publisher page.
- **ORCIDs are often missing.** Some publishers include `owl:sameAs` ORCID links; many don't. Search separately.
- **CrossRef can include non-authors** (e.g. guest editors). Verify against the actual paper.

### ORCID lookup

```bash
scripts/orcid-search.sh Kuhn Tobias              # search by name (handles diacritics)
scripts/orcid-verify.sh 0000-0002-1267-0234      # show name + employment history
```

Common names may return multiple results — verify by checking works or employment history. Use ORCID URIs (e.g. `orcid:0000-0002-1267-0234`) in nanopubs.

For works disambiguation: `scripts/orcid-works.sh 0000-0002-1267-0234`

### ROR lookup

```bash
scripts/ror-search.sh "Vrije Universiteit Amsterdam"
```

To verify a specific ROR: `scripts/ror-verify.sh 008xxew50`

### Checking existing doibot nanopubs

```bash
scripts/check-author-nanopubs.sh 0000-0002-1267-0234   # prints query URL for nanodash
```

## Workflow: creating/updating nanopubs

1. Edit the output file in `<bot>/output/`
2. Sign and publish: `scripts/sign-publish.sh <bot> <name>`

When updating an existing nanopub:
- Update the `dct:created` timestamp: `scripts/timestamp.sh`
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
