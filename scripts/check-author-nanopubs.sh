#!/usr/bin/env bash
# Show the nanodash query URL listing existing doibot nanopubs for an author.
# Usage: scripts/check-author-nanopubs.sh <orcid>
# <orcid> can be a bare ID (0000-0002-1267-0234) or full URI.

ORCID="${1:?Usage: scripts/check-author-nanopubs.sh <orcid>}"
ORCID="${ORCID#https://orcid.org/}"

echo "https://nanodash.knowledgepixels.com/query?runquery=RA7X8hbsozQjZCv4RfWGIgzEA6qr9Ds6RL5kQnB7GHThc/get-papers-for-author&queryparam_author=https://orcid.org/${ORCID}"
