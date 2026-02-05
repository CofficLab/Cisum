#!/bin/bash
#
# get-latest-beta-version.sh - Get the latest beta version number
#
# This script finds the most recent beta version tag and extracts
# the base version number for official release.
#
# Usage: ./scripts/get-latest-beta-version.sh
# Output: <version> (e.g., 3.1.7)

set -euo pipefail

# Find all p* tags (pre-release), sort by version number
PRE_TAGS=$(git tag -l "p*" 2>/dev/null | sort -V)

if [ -z "$PRE_TAGS" ]; then
  # No pre-release tags found
  echo "Error: No pre-release tags found" >&2
  exit 1
fi

# Get the latest pre-release tag
LATEST_PRE_TAG=$(echo "$PRE_TAGS" | tail -n 1)

# Extract base version number (remove p prefix)
BASE_VERSION=$(echo "$LATEST_PRE_TAG" | sed 's/^p//')

echo "📦 Latest Pre-release Tag: $LATEST_PRE_TAG" >&2
echo "🎯 Base Version for Release: $BASE_VERSION" >&2

# Output the base version
echo "$BASE_VERSION"
