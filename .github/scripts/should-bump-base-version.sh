#!/bin/bash
#
# should-bump-base-version.sh - Check if base version should be bumped
#
# This script checks if there are new feature commits since the last tag
# that would require incrementing the base version number.
#
# Usage: ./scripts/should-bump-base-version.sh
# Output: "true" or "false"

set -euo pipefail

# Get the most recent tag (any format: v1.2.3 or 1.2.3-beta.1)
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
  # No tags exist, should bump
  echo "true"
  exit 0
fi

# Get all commit messages since the last tag
COMMITS=$(git log ${LAST_TAG}..HEAD --pretty=format:%s 2>/dev/null || echo "")

if [ -z "$COMMITS" ]; then
  # No commits, don't bump
  echo "false"
  exit 0
fi

# Check for features or breaking changes
if echo "$COMMITS" | grep -qE "BREAKING CHANGE|^feat!|^fix!|^refactor!"; then
  echo "true"
  exit 0
fi

if echo "$COMMITS" | grep -qE "^feat:"; then
  echo "true"
  exit 0
fi

# Default: only bug fixes or chore, don't bump base version
echo "false"
