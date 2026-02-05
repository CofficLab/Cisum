#!/bin/bash
#
# bump-version.sh - Calculate next version based on Conventional Commits
#
# This script analyzes commits since the last tag and determines the
# appropriate version increment (major, minor, or patch) following
# Semantic Versioning 2.0.0 and Conventional Commits specifications.
#
# Usage: ./scripts/bump-version.sh
# Output: major|minor|patch
#

set -euo pipefail

# Get the most recent tag, or default to 0.0.0 if no tags exist
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")

# Get all commit messages since the last tag
COMMITS=$(git log ${LAST_TAG}..HEAD --pretty=format:%s 2>/dev/null || echo "")

# If no commits found, default to patch
if [ -z "$COMMITS" ]; then
  echo "patch"
  exit 0
fi

# Check for breaking changes
# BREAKING CHANGE: in commit body
# feat!: or fix!: in commit subject (conventional commits with !)
if echo "$COMMITS" | grep -qE "BREAKING CHANGE|^feat!|^fix!|^refactor!"; then
  echo "major"
  exit 0
fi

# Check for new features
if echo "$COMMITS" | grep -qE "^feat:"; then
  echo "minor"
  exit 0
fi

# Default to patch for bug fixes and other changes
echo "patch"
