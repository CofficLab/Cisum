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

# Find all beta tags (without p prefix), sort by version number
BETA_TAGS=$(git tag -l "*-beta.*" 2>/dev/null | grep -v '^p' | sort -V)

if [ -z "$BETA_TAGS" ]; then
  # No beta tags found
  echo "Error: No beta tags found" >&2
  exit 1
fi

# Get the latest beta tag
LATEST_BETA_TAG=$(echo "$BETA_TAGS" | tail -n 1)

# Extract base version number (remove -beta.N suffix)
BASE_VERSION=$(echo "$LATEST_BETA_TAG" | sed -E 's/-beta\.[0-9]+$//')

echo "📦 Latest Beta Tag: $LATEST_BETA_TAG" >&2
echo "🎯 Base Version for Release: $BASE_VERSION" >&2

# Output the base version
echo "$BASE_VERSION"
