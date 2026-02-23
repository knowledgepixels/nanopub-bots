#!/usr/bin/env bash
# Print the current local timestamp in nanopub format (ISO 8601 with timezone offset).
# Usage: scripts/timestamp.sh

TZ_RAW=$(date +%z)  # e.g. +0100 or -0500
TZ_FMT="${TZ_RAW:0:3}:${TZ_RAW:3}"  # e.g. +01:00 or -05:00
echo "$(date +"%Y-%m-%dT%H:%M:%S.000")${TZ_FMT}"
