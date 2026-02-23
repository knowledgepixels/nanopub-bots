#!/usr/bin/env bash
# Fetch RDF metadata for a DOI via content negotiation.
# Usage: scripts/doi-meta.sh <doi>
# Returns Turtle RDF with title, authors, ORCIDs, affiliations, etc.

set -euo pipefail

DOI="${1:?Usage: scripts/doi-meta.sh <doi>}"
DOI="${DOI#https://doi.org/}"  # strip prefix if accidentally included

curl -sL -H 'Accept: text/turtle' "https://doi.org/${DOI}"
