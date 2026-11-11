#!/usr/bin/env bash
# Sign a nanopub using the bot's key.
# Usage: scripts/sign.sh <bot> <name>
#   <bot>  — bot directory name (doibot, biodivbot, ai-in-edu-bot)
#   <name> — file basename without .trig extension
# Reads <bot>/output/<name>.trig, writes <bot>/signed/signed.<name>.trig

set -euo pipefail

BOT="${1:?Usage: scripts/sign.sh <bot> <name>}"
NAME="${2:?Usage: scripts/sign.sh <bot> <name>}"
NAME="${NAME%.trig}"  # strip .trig if accidentally included

KEY_FILE="$HOME/.nanopub/${BOT}_id_rsa"
INPUT="${BOT}/output/${NAME}.trig"
OUTPUT="${BOT}/signed/signed.${NAME}.trig"

# The bot itself is the one and only signer (never the ORCID from ~/.nanopub/profile.yml).
case "$BOT" in
    doibot)        SIGNER="https://w3id.org/np/RAkkUz7qBJ-BIOCHV_4WCTgHCdTyI25_bnRuw166SXjwM/DOI-bot" ;;
    biodivbot)     SIGNER="https://w3id.org/np/RAcrl-l7bWTBLTblgq2jjQwJvlADseCwSIX5SKdCyuHS8/biodiv-bot" ;;
    ai-in-edu-bot) SIGNER="https://w3id.org/np/RAVkNLhqtCY6sVZMWqyyUkzmHJyd8-0naSJ_S_CNbabf0/ai-in-edu-bot" ;;
    *) echo "Error: unknown bot (no signer IRI): $BOT" >&2; exit 1 ;;
esac

if [[ ! -f "$KEY_FILE" ]]; then
    echo "Error: key file not found: $KEY_FILE" >&2
    exit 1
fi
if [[ ! -f "$INPUT" ]]; then
    echo "Error: input file not found: $INPUT" >&2
    exit 1
fi

./np sign -k "$KEY_FILE" -s "$SIGNER" "$INPUT" -o "$OUTPUT"

SIGNERS=$(grep -A8 'npx:hasAlgorithm' "$OUTPUT" | grep -o 'npx:signedBy[^.]*' | tr ',' '\n' | grep -c .)
if [[ "$SIGNERS" -ne 1 ]]; then
    echo "Error: $OUTPUT has $SIGNERS npx:signedBy values (expected exactly 1: $SIGNER)" >&2
    exit 1
fi
echo "Signed: $OUTPUT"
