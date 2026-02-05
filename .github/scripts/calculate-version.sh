#!/bin/bash
#
# calculate-version.sh - Calculate the next semantic version
#
# This script calculates the next version number based on the
# increment type determined by bump-version.sh and updates
# the Xcode project file.
#
# Usage: ./.github/scripts/calculate-version.sh
# Output: <version> (e.g., 1.2.3)
#

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the increment type (major, minor, or patch)
INCREMENT_TYPE=$("$SCRIPT_DIR/bump-version.sh")

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

echo "📦 Current Version: $CURRENT_VERSION" >&2
echo "📊 Increment Type: $INCREMENT_TYPE" >&2

# Parse the version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

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

# Update the Xcode project file
sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION/MARKETING_VERSION = $NEW_VERSION/" "$PROJECT_FILE"

# Verify the update
UPDATED_VERSION=$(grep -o 'MARKETING_VERSION = [^"]*' "$PROJECT_FILE" | head -n 1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')

if [ "$UPDATED_VERSION" != "$NEW_VERSION" ]; then
  echo "Error: Failed to update version in project file" >&2
  exit 1
fi

echo "✅ Version updated successfully in project file" >&2

# Output the new version
echo "$NEW_VERSION"
