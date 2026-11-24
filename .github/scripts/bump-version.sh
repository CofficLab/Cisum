#!/bin/bash
#
# bump-version.sh - Calculate next version based on Conventional Commits
#
# This script analyzes commits since the last tag and determines the
# appropriate version increment (major, minor, or patch) following
# Semantic Versioning 2.0.0 and Conventional Commits specifications.
#
# Usage: ./bump-version.sh
# Output: major|minor|patch
#

set -euo pipefail

# Get the most recent tag starting with 'v', or default to v0.0.0 if no tags exist
LAST_TAG=$(git describe --tags --match "v*" --abbrev=0 2>/dev/null || echo "v0.0.0")

# Subjects drive the type prefixes; full messages are needed for footers.
SUBJECTS=$(git log ${LAST_TAG}..HEAD --pretty=format:%s 2>/dev/null || echo "")
MESSAGES=$(git log ${LAST_TAG}..HEAD --pretty=format:%B 2>/dev/null || echo "")

# If no commits found, default to patch
if [ -z "$SUBJECTS" ]; then
  echo "patch"
  exit 0
fi

# Check for breaking changes:
# - BREAKING CHANGE: footer anywhere in the commit body
# - feat(scope)!: / fix!: / refactor!: / perf!: in the subject (scope optional)
if echo "$MESSAGES" | grep -qE '^BREAKING CHANGE:'; then
  echo "major"
  exit 0
fi

if echo "$SUBJECTS" | grep -qE '^(feat|fix|refactor|perf)(\([^)]*\))?!:'; then
  echo "major"
  exit 0
fi

# Check for new features (scope optional)
if echo "$SUBJECTS" | grep -qE '^feat(\([^)]*\))?:'; then
  echo "minor"
  exit 0
fi

# Default to patch for bug fixes and other changes
echo "patch"
