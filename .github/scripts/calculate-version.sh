#!/bin/bash
#
# calculate-version.sh - Calculate the next semantic version
#
# This script calculates the next version number based on the
# increment type determined by bump-version.sh and updates
# the Xcode project file.
#
# Supports both the legacy project.pbxproj property list and Xcode 27's
# JSON project.xcproj format.
#
# Usage: ./.github/scripts/calculate-version.sh
# Output: <version> (e.g., 1.2.3)
#

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/scripts/xcode-project.sh
source "$SCRIPT_DIR/xcode-project.sh"

# Get the increment type (major, minor, or patch)
INCREMENT_TYPE=$("$SCRIPT_DIR/bump-version.sh")

# Find the Xcode project file (prefers project.xcproj, excludes .build)
PROJECT_FILE=$(xcode_project_file "$(pwd)") || {
  echo "Error: Cannot find Xcode project file (project.xcproj or project.pbxproj)" >&2
  exit 1
}

# Get current version from MARKETING_VERSION (use main app version)
CURRENT_VERSION=$(xcode_project_setting "$PROJECT_FILE" MARKETING_VERSION) || {
  echo "Error: Cannot find MARKETING_VERSION in project file" >&2
  exit 1
}

# Keep only the numeric x.y or x.y.z part of the value
CURRENT_VERSION=$(echo "$CURRENT_VERSION" | grep -o '[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?' || true)

if [ -z "$CURRENT_VERSION" ]; then
  echo "Error: MARKETING_VERSION in project file is not a semantic version" >&2
  exit 1
fi

echo "📦 Current Version: $CURRENT_VERSION" >&2
echo "📊 Increment Type: $INCREMENT_TYPE" >&2

# Parse the version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
PATCH=${PATCH:-0}

# Calculate new version based on increment type
case $INCREMENT_TYPE in
  major)
    NEW_MAJOR=$((MAJOR + 1))
    NEW_VERSION="${NEW_MAJOR}.0.0"
    ;;
  minor)
    NEW_MINOR=$((MINOR + 1))
    NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"
    ;;
  patch)
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
    ;;
  *)
    echo "Error: Unknown increment type '$INCREMENT_TYPE'" >&2
    exit 1
    ;;
esac

echo "🆕 New Version: $NEW_VERSION" >&2

# Update every MARKETING_VERSION entry that still matches the current version.
# This keeps the main app and widget extension aligned without touching targets
# that intentionally keep their own version (for example the UI test bundle).
xcode_project_set_setting "$PROJECT_FILE" MARKETING_VERSION "$CURRENT_VERSION" "$NEW_VERSION"

# Verify the update - check all occurrences
VERSION_COUNT=$(xcode_project_setting_count "$PROJECT_FILE" MARKETING_VERSION "$NEW_VERSION")
echo "✅ Updated $VERSION_COUNT version entries in project file" >&2

# Verify at least one entry was updated
if [ "$VERSION_COUNT" -eq 0 ]; then
  echo "Error: Failed to update version in project file" >&2
  exit 1
fi

UPDATED_VERSION=$(xcode_project_setting "$PROJECT_FILE" MARKETING_VERSION || true)

if [ "$UPDATED_VERSION" != "$NEW_VERSION" ]; then
  echo "Error: Failed to update version in project file" >&2
  exit 1
fi

echo "✅ All versions updated successfully" >&2

# Output the new version
echo "$NEW_VERSION"
