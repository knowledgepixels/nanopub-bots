#!/usr/bin/env bash
# Publish a signed nanopub to the nanopub network.
# Usage: scripts/publish.sh <bot> <name>
#   <bot>  — bot directory name (doibot, biodivbot, ai-in-edu-bot)
#   <name> — file basename without .trig extension
# Publishes <bot>/signed/signed.<name>.trig

set -euo pipefail

BOT="${1:?Usage: scripts/publish.sh <bot> <name>}"
NAME="${2:?Usage: scripts/publish.sh <bot> <name>}"
NAME="${NAME%.trig}"

SIGNED="${BOT}/signed/signed.${NAME}.trig"

if [[ ! -f "$SIGNED" ]]; then
    echo "Error: signed file not found: $SIGNED" >&2
    exit 1
fi

./np publish "$SIGNED"
