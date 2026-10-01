#!/bin/bash
#
# calculate-beta-version.sh - Calculate the next beta version with iteration
#
# This script calculates the next beta version number by:
# 1. Getting the current version from Xcode project
# 2. Finding the last beta tag for this version
# 3. Incrementing the iteration number
#
# Supports both the legacy project.pbxproj property list and Xcode 27's
# JSON project.xcproj format.
#
# Usage: ./scripts/calculate-beta-version.sh
# Output: <version>-beta.<iteration> (e.g., 3.1.6-beta.2)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/scripts/xcode-project.sh
source "$SCRIPT_DIR/xcode-project.sh"

# Find the Xcode project file
PROJECT_FILE=$(xcode_project_file "$(pwd)") || {
  echo "Error: Cannot find Xcode project file (project.xcproj or project.pbxproj)" >&2
  exit 1
}

# Get current version from MARKETING_VERSION
CURRENT_VERSION=$(xcode_project_setting "$PROJECT_FILE" MARKETING_VERSION) || {
  echo "Error: Cannot find MARKETING_VERSION in project file" >&2
  exit 1
}

CURRENT_VERSION=$(echo "$CURRENT_VERSION" | grep -o '[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?' || true)

if [ -z "$CURRENT_VERSION" ]; then
  echo "Error: MARKETING_VERSION in project file is not a semantic version" >&2
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
