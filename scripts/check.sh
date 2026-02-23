#!/usr/bin/env bash
# Validate a nanopub (unsigned output file).
# Usage: scripts/check.sh <bot> <name>
#   <bot>  — bot directory name (doibot, biodivbot, ai-in-edu-bot)
#   <name> — file basename without .trig extension

set -euo pipefail

BOT="${1:?Usage: scripts/check.sh <bot> <name>}"
NAME="${2:?Usage: scripts/check.sh <bot> <name>}"
NAME="${NAME%.trig}"

INPUT="${BOT}/output/${NAME}.trig"

if [[ ! -f "$INPUT" ]]; then
    echo "Error: file not found: $INPUT" >&2
    exit 1
fi

./np check "$INPUT"
