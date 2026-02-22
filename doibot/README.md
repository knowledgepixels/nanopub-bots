# DOI-Bot

Bot ID: https://w3id.org/np/RAkkUz7qBJ-BIOCHV_4WCTgHCdTyI25_bnRuw166SXjwM/DOI-bot

Key file: ~/.nanopub/doibot_id_rsa

## Creating a nanopub for a paper

Given a DOI (e.g. `10.7717/peerj-cs.281`), gather the following metadata:

1. **From Crossref** (`https://api.crossref.org/works/<DOI>`): title, publication date, journal name and ISSN, author names and ORCIDs (in the `ORCID` field of each author entry), affiliation strings.
2. **ROR IDs for affiliations**: look up each unique affiliation at https://ror.org to find the ROR ID.
3. **Missing ORCIDs**: if Crossref doesn't list an ORCID for an author, search https://orcid.org. If still not found, use a blank node (e.g. `:firstname-lastname`) instead of an `orcid:` URI.

### File structure

Use an existing output file (e.g. `output/10.7717_peerj-cs.387.trig`) as a template. The filename convention is the DOI with `/` replaced by `_`.

- **Assertion graph**: article metadata (`fabio:Article`), `dct:title`, `dct:date`, `dct:isPartOf` (journal/proceedings ISSN URI), `bibo:authorList` with numbered `rdf:_N` entries, author details (`foaf:name`, `schema:affiliation`), affiliation labels (`foaf:name` on ROR URIs).
- **Provenance graph**: `prov:wasAttributedTo` listing all authors that have ORCIDs, `prov:wasDerivedFrom` the DOI URI.
- **Pubinfo graph**: `dct:created` (current timestamp), `dct:creator` (DOI-bot URI), `dct:license` (CC0), `npx:hasNanopubType fabio:ScholarlyWork`, `npx:introduces` (DOI URI), `rdfs:label` (paper title), `foaf:name` repeated for each author with an ORCID, `:sig npx:signedBy` (DOI-bot URI).

### Journal and proceedings volume

Every nanopub (except standalone books) **must** include a `dct:isPartOf` triple in the assertion graph linking the paper to its journal or proceedings volume. Use an ISSN-based URI as the identifier whenever an ISSN is available (e.g. `<http://id.crossref.org/issn/2052-4463>`). If no ISSN exists (e.g. some workshop proceedings), a descriptive local identifier may be used instead.

### Sign and publish

```bash
./np sign -k ~/.nanopub/doibot_id_rsa doibot/output/<file>.trig -o doibot/signed/signed.<file>.trig
./np publish doibot/signed/signed.<file>.trig
```