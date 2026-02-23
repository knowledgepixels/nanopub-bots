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

### Doibot: generate a draft nanopub from a DOI

```bash
scripts/doi-to-trig.sh 10.1145/3460210.3493567
```

Fetches CrossRef metadata, auto-searches ORCID for each author, and writes a ready-to-edit draft to `doibot/output/<name>.trig`. Authors whose ORCID was auto-found are marked `# VERIFY`; unresolved ones are left as blank nodes (`:<firstname>-<lastname>`) with `# TODO` comments listing any candidates. After reviewing and fixing the draft, sign and publish with `scripts/sign-publish.sh doibot <name>`.

**Always verify author order against the publisher page** — CrossRef order is unreliable.

**Do not run doi-to-trig.sh calls in parallel** — the script uses a per-process temp file for CrossRef data (now fixed), but the ORCID search calls inside also write to shared temp paths. Run sequentially.

### Doibot: inspect CrossRef metadata

```bash
scripts/crossref-meta.sh 10.1145/3460210.3493567   # title, type, author order, ISSN, abstract
scripts/orcid-search-all.sh 10.1145/3460210.3493567 # ORCID lookup for all authors at once
```

Use these to manually inspect what `doi-to-trig.sh` will use, or to troubleshoot.

### Doibot: find papers without nanopubs

```bash
scripts/find-missing-nanopubs.sh 0000-0002-1267-0234
```

Compares an author's ORCID works list against `doibot/output/` and lists papers that don't have a nanopub yet.

**Items to skip** in the output:
- Preprints: `10.48550/arXiv.*`, `10.1101/*` (bioRxiv/medRxiv), `10.31219/osf.io/*`, `10.7287/peerj.preprints.*`
- Author corrections and addenda (title starts with "Author Correction:", "Addendum:", "Authors' Response to Peer Reviews")
- Items typed `[other]` (usually preprints, workshop abstracts, or non-standard documents)
- Repository DOIs like `10.5167/*` (UZH institutional repository) — not in CrossRef

**Malformed DOIs:** Some old ORCID entries use hyphens before chapter numbers instead of underscores (e.g. `10.1007/978-3-642-38288-8-33`). Try replacing the final `-` with `_` — the correctly formatted version may already have a nanopub.

### DOI metadata (raw Turtle)

```bash
scripts/doi-meta.sh 10.1007/11799511_7
```

Returns raw Turtle RDF from DOI content negotiation. Useful for checking what the DOI resolver returns directly. Note: `doi-to-trig.sh` uses CrossRef instead, which has better-structured data.

### ORCID lookup

```bash
scripts/orcid-search.sh Kuhn Tobias              # search by name (handles diacritics)
scripts/orcid-verify.sh 0000-0002-1267-0234      # show name + employment history
scripts/orcid-works.sh 0000-0002-1267-0234       # list works (for disambiguation)
```

Common names may return multiple results — verify by checking works or employment history. Use ORCID URIs (e.g. `orcid:0000-0002-1267-0234`) in nanopubs.

**Do not run orcid-verify.sh / orcid-works.sh in parallel** — stdout gets interleaved and results become unreadable. Run sequentially.

**Disambiguation heuristic:** If ORCID search returns exactly 1 match for someone in a specialized field, it's generally safe to accept. When multiple matches exist, `orcid-works.sh` is usually faster than `orcid-verify.sh` for disambiguation.

### Frequently appearing co-authors (Tobias Kuhn's papers)

These ORCIDs come up repeatedly and don't need re-lookup:

| Name | ORCID |
|---|---|
| Michel Dumontier | 0000-0003-4727-9435 |
| Michael Krauthammer | 0000-0002-4808-1845 |
| Egon Willighagen | 0000-0001-7542-0286 |
| Albert Meroño-Peñuela | 0000-0003-4646-5842 |
| Victor de Boer | 0000-0001-9079-039X |
| Guus Schreiber | 0000-0002-2400-1185 |
| Martin Volk | 0000-0002-2063-4516 |
| Kurt Winkler | 0000-0003-0197-9743 |

### ROR lookup

```bash
scripts/ror-search.sh "Vrije Universiteit Amsterdam"
scripts/ror-verify.sh 008xxew50
```

### Checking existing doibot nanopubs

```bash
scripts/check-author-nanopubs.sh 0000-0002-1267-0234   # prints query URL for nanodash
```

## Workflow: creating/updating nanopubs

**Creating a new doibot nanopub:**
1. `scripts/doi-to-trig.sh <doi>` — generates the draft, auto-resolves ORCIDs
2. Review the draft in `doibot/output/<name>.trig`: fix `# TODO` items, verify `# VERIFY` ORCIDs, check author order against publisher page, add affiliations if known
3. `scripts/sign-publish.sh doibot <name>`

**Other bots** (biodivbot, ai-in-edu-bot): edit the output file manually, then sign and publish.

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
