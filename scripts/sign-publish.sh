#!/usr/bin/env bash
# Sign and publish a nanopub in one step.
# Usage: scripts/sign-publish.sh <bot> <name>
#   <bot>  — bot directory name (doibot, biodivbot, ai-in-edu-bot)
#   <name> — file basename without .trig extension

set -euo pipefail

BOT="${1:?Usage: scripts/sign-publish.sh <bot> <name>}"
NAME="${2:?Usage: scripts/sign-publish.sh <bot> <name>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/sign.sh" "$BOT" "$NAME"
"$SCRIPT_DIR/publish.sh" "$BOT" "$NAME"
