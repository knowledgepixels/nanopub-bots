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

if [[ ! -f "$KEY_FILE" ]]; then
    echo "Error: key file not found: $KEY_FILE" >&2
    exit 1
fi
if [[ ! -f "$INPUT" ]]; then
    echo "Error: input file not found: $INPUT" >&2
    exit 1
fi

./np sign -k "$KEY_FILE" "$INPUT" -o "$OUTPUT"
echo "Signed: $OUTPUT"
