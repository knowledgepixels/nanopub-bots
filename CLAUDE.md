# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **data repository** containing nanopublications created by three specialized bots. Nanopublications are minimalist semantic publications in RDF Trig format, cryptographically signed with RSA keys.

The project creator is Tobias Kuhn (ORCID: 0000-0002-1267-0234).

## Related: the generic nanopub skill

The sibling repo **`../nanopub-skill`** (`SKILL.md` + downloaded `queries/`, `assertion-templates/`, `resource-views/`) is the canonical reference for *general* nanopub work — querying the network via the Nanopub Query API, grlc query templates, resource views, the `spaces`/`trust` admin repos, presets, and the full retract/supersede CLI details. Consult it when a task goes beyond this repo's bot-generation workflow. (Ignore `../nanopub-agent-utilities` — it is deprecated.)

**This `CLAUDE.md` is authoritative for the bots.** Where the generic skill's defaults differ, follow this file:

| Generic skill default | This repo's rule |
|---|---|
| `dct:license` = CC-BY 4.0 | **CC0** (see License below) |
| Timestamps via `date -u` (UTC) | **Local time, never `date -u`** (`scripts/timestamp.sh`) |
| Work in `tmp/`, download jar from Maven | `./np` wrapper, `output/`+`signed/`, `scripts/` |

doibot nanopubs **do** carry `nt:wasCreatedFrom*Template` links so they render through Nanodash's template UI — see [Template links](#template-links) for the exact URIs.

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

The `./np` wrapper script runs the nanopub-java CLI from the sibling `../nanopub-java` repo. The wrapper needs the **fat** jar (`nanopub-*-jar-with-dependencies.jar`), which upstream now builds only under the `cli` Maven profile. If the JAR isn't built yet:

```bash
mvn -f ../nanopub-java clean package -DskipTests -P cli
```

(Plain `mvn package` without `-P cli` produces only the thin jar and the `./np` wrapper will report "No nanopub jar found".)

Raw CLI reference (use the scripts below for common operations):

```bash
./np sign -k <key> <file.trig> -o <out.trig>  # sign with specific key
./np publish <signed.trig>                     # publish to nanopub network
./np check <file.trig>                         # validate a nanopub
# Retract a nanopub (must specify -s <signer-IRI> or you'll get a NullPointerException):
./np retract -i <nanopub-uri-or-file> -k <key> -s <signer-IRI> -p
# For doibot: -s https://w3id.org/np/RAkkUz7qBJ-BIOCHV_4WCTgHCdTyI25_bnRuw166SXjwM/DOI-bot
# (The docs imply -s must be an ORCID, but any IRI including the bot IRI works.)
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

**Before superseding, resolve the actual head of the chain** — a known URI may not be the latest version. Query `get-latest-version-of-np` and supersede the head it returns:

```bash
curl -s "https://query.knowledgepixels.com/api/RAiRsB2YywxjsBMkVRTREJBooXhf2ZOHoUs5lxciEl37I/get-latest-version-of-np?np=<uri>"
```

If the chain has **forked** into two heads (e.g. a republish built on a stale base), publish one new version with `npx:supersedes` triples for **both** heads to collapse the fork.

**`npx:supersedes` requires the same signing key** as the original (same public-key hash). For a given bot this always holds; if the keys would differ, use `prov:wasDerivedFrom` instead.

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

After signing, confirm `npx:signedBy` in the signed file is the correct ORCID — not the all-zeros `orcid:0000-0000-0000-0000` placeholder. That value is written when the Python `nanopub` library overwrites `~/.nanopub/profile.yml`; if you see it, restore the profile and re-sign before publishing.

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

### Checking existing doibot nanopubs on the network

**Before creating a nanopub for a paper, check whether one already exists on the network.** The `find-missing-nanopubs.sh` script only compares against local `doibot/output/` files — it will miss papers that were published by a previous session but whose local files were deleted.

Query the nanopub network (returns SPARQL JSON):

```bash
# All papers by an author on the network:
curl -s "https://query.knowledgepixels.com/api/RA7X8hbsozQjZCv4RfWGIgzEA6qr9Ds6RL5kQnB7GHThc/get-papers-for-author?author=https://orcid.org/0000-0002-1267-0234" | python3 -c "import sys,json; [print(b['label']['value'], '|', b['np']['value']) for b in json.load(sys.stdin)['results']['bindings']]"
```

Or use the nanodash UI: `https://nanodash.knowledgepixels.com/query?runquery=RA7X8hbsozQjZCv4RfWGIgzEA6qr9Ds6RL5kQnB7GHThc/get-papers-for-author&queryparam_author=https://orcid.org/0000-0002-1267-0234`

**DOI case sensitivity:** DOIs are case-insensitive but the network treats them as separate URIs. If a paper already has a nanopub with `https://doi.org/10.1162/COLI_a_00168` (uppercase), creating one with the lowercase form will result in a duplicate. Always check the network before creating.

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

The specific type (in the assertion) **must be one of the values the doibot article template allows** (see Template links). That template's allowed types are `fabio:Article`, `fabio:BookChapter`, `fabio:ConferencePaper`, plus `InUsePaper`, `JournalEditorial`, `MethodsPaper`, `PositionPaper`, `ResearchPaper`, `ResourcePaper`, `ReviewPaper`, `ScholarlyWork`. Using a type outside that list makes the `rdf:type` triple fail to match the template.

### Template links

doibot nanopubs carry `nt:wasCreatedFrom*Template` links in pubinfo so they render through Nanodash's template UI. `doi-to-trig.sh` emits these automatically; when hand-editing, keep them in sync (the prefix `ns1:` = `<http://purl.org/np/>`, `nt:` = `<https://w3id.org/np/o/ntemplate/>`):

```turtle
  nt:wasCreatedFromProvenanceTemplate ns1:RAGXx_k9eQMnXaCbsXMsJbGClwZtQEGNg0GVJu6amdAVw;
  nt:wasCreatedFromPubinfoTemplate <https://w3id.org/np/RACJ58Gvyn91LqCKIO9zu1eijDQIeEff28iyDrJgjSJF8>,
    <https://w3id.org/np/RAoTD7udB2KtUuOuAe74tJi1t3VzK0DyWS7rYVAq1GRvw>,
    <https://w3id.org/np/RAukAcWHRDlkqxk7H2XNSegc1WnHI569INvNr-xdptDGI>;
  nt:wasCreatedFromTemplate <https://w3id.org/np/RA6NErVvGFJ1AflK02qqnB4jiQeF2EHl7mlbA7kp0d-lk> .
```

- **Assertion template** `RA6NErVv…` — "Describing core article metadata", a doibot-specific **derived** version of the community template `RAYRjIrbLSDIX5Mp1cb6MK4vRV0Vd5o0TZ8NTIEHwCPOI`. The original (published at petapico.org with a key we don't hold) (a) restricted the type list and (b) required every author to be an ORCID. The derived version adds `fabio:Article` + `fabio:ConferencePaper` to the type list and relaxes the author placeholder regex to `https?://.+` so authors **without an ORCID** are accepted as local URIs. Because the original was signed with a different key, the derived template links back via `prov:wasDerivedFrom` (in its provenance graph), **not** `npx:supersedes`. Signed with the local default key (Tobias Kuhn's ORCID). To revise it, derive again (download the latest into `../nanopub-skill` first); do not try to supersede the petapico original.
- **Provenance template** `RAGXx_k9…` — "Attributed to myself/others and (partly) derived from an existing entity": `prov:wasAttributedTo` (repeatable) + `prov:wasDerivedFrom`. This matches the doibot provenance (authors + DOI). **Do not** use `RANwQa4…` ("Attributed to myself") — it only covers `wasAttributedTo nt:CREATOR` and has no `wasDerivedFrom`, so it fails to match.
- **Pubinfo templates** — License (`RACJ58Gv…`, CC0 is an allowed value), Supersedes (`RAoTD7ud…`, listed but unused), Creator (`RAukAcWHR…`, the DOI-bot IRI).

**Authors without an ORCID:** use a local blank-node-style URI (`:firstname-lastname`) carrying `foaf:name` (and `schema:affiliation`); the derived template accepts these. Only ORCID authors go into `prov:wasAttributedTo` — so the provenance template needs ≥1 ORCID author to match (a paper with zero ORCID authors would need its provenance reconsidered).

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
