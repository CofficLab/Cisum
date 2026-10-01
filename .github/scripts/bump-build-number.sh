#!/bin/bash
#
# bump-build-number.sh - Increment the Xcode build number
#
# Replaces `agvtool next-version -all`, which only understands the legacy
# project.pbxproj format and fails on Xcode 27's JSON project.xcproj.
#
# The build number is incremented for every target that shares the main
# app's current build number, keeping the app and its widget extension in
# sync while leaving targets with an independent build number untouched.
#
# Usage: ./.github/scripts/bump-build-number.sh
# Output: <build number> (e.g., 519)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/scripts/xcode-project.sh
source "$SCRIPT_DIR/xcode-project.sh"

PROJECT_FILE=$(xcode_project_file "$(pwd)") || {
  echo "Error: Cannot find Xcode project file (project.xcproj or project.pbxproj)" >&2
  exit 1
}

CURRENT_BUILD=$(xcode_project_setting "$PROJECT_FILE" CURRENT_PROJECT_VERSION) || {
  echo "Error: Cannot find CURRENT_PROJECT_VERSION in project file" >&2
  exit 1
}

case "$CURRENT_BUILD" in
  ''|*[!0-9]*)
    echo "Error: CURRENT_PROJECT_VERSION '$CURRENT_BUILD' is not a number" >&2
    exit 1
    ;;
esac

NEW_BUILD=$((CURRENT_BUILD + 1))

xcode_project_set_setting "$PROJECT_FILE" CURRENT_PROJECT_VERSION "$CURRENT_BUILD" "$NEW_BUILD"

UPDATED_COUNT=$(xcode_project_setting_count "$PROJECT_FILE" CURRENT_PROJECT_VERSION "$NEW_BUILD")

if [ "$UPDATED_COUNT" -eq 0 ]; then
  echo "Error: Failed to update CURRENT_PROJECT_VERSION" >&2
  exit 1
fi

echo "🔢 Build Number: $CURRENT_BUILD -> $NEW_BUILD ($UPDATED_COUNT target(s))" >&2

echo "$NEW_BUILD"
