#!/bin/bash
#
# calculate-beta-version.sh - Calculate the next beta version with iteration
#
# This script calculates the next beta version number by:
# 1. Getting the current version from Xcode project
# 2. Finding the last beta tag for this version
# 3. Incrementing the iteration number
#
# Usage: ./scripts/calculate-beta-version.sh
# Output: <version>-beta.<iteration> (e.g., 3.1.6-beta.2)

set -euo pipefail

# Find the Xcode project file
PROJECT_FILE=$(find $(pwd) -type f -name "*.pbxproj" | head -n 1)

if [ -z "$PROJECT_FILE" ]; then
  echo "Error: Cannot find .pbxproj file" >&2
  exit 1
fi

# Get current version from MARKETING_VERSION
CURRENT_VERSION=$(grep -o 'MARKETING_VERSION = [^"]*' "$PROJECT_FILE" | head -n 1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')

if [ -z "$CURRENT_VERSION" ]; then
  echo "Error: Cannot find MARKETING_VERSION in project file" >&2
  exit 1
fi

echo "📦 Current Base Version: $CURRENT_VERSION" >&2

# Find all beta tags for this version (sorted by iteration number)
BETA_TAGS=$(git tag -l "${CURRENT_VERSION}-beta.*" 2>/dev/null | sort -V)

if [ -z "$BETA_TAGS" ]; then
  # No beta tags for this version, start with .1
  NEW_VERSION="${CURRENT_VERSION}-beta.1"
  echo "🆕 First beta iteration for version $CURRENT_VERSION" >&2
else
  # Get the last beta tag and extract iteration number
  LAST_BETA_TAG=$(echo "$BETA_TAGS" | tail -n 1)
  LAST_ITERATION=$(echo "$LAST_BETA_TAG" | grep -o '[0-9]\+$' || echo "0")

  # Increment iteration
  NEW_ITERATION=$((LAST_ITERATION + 1))
  NEW_VERSION="${CURRENT_VERSION}-beta.${NEW_ITERATION}"

  echo "📈 Previous beta: $LAST_BETA_TAG" >&2
  echo "🔢 New iteration: $NEW_ITERATION" >&2
fi

echo "🏷️  New Beta Version: $NEW_VERSION" >&2

# Output the new version
echo "$NEW_VERSION"
