#!/bin/bash
#
# generate-changelog.sh - Generate release notes from commits
#
# This script analyzes git commits since the last tag and generates
# release notes following Conventional Commits format.
#
# Usage: ./scripts/generate-changelog.sh <output_file>
# Output: Markdown formatted changelog

set -euo pipefail

OUTPUT_FILE=${1:-""}

if [ -z "$OUTPUT_FILE" ]; then
  echo "Error: Output file path required" >&2
  echo "Usage: $0 <output_file>" >&2
  exit 1
fi

# Resolve the release tag and the previous tag from complete reachable history.
# The workflow passes RELEASE_TAG because a branch-triggered release (v*) does
# not have the release tag checked out yet.
if [ -n "${GITHUB_REF_NAME:-}" ]; then
  CURRENT_REF="$GITHUB_REF_NAME"
else
  CURRENT_REF=$(git symbolic-ref --short -q HEAD 2>/dev/null || git describe --tags --exact-match HEAD 2>/dev/null || echo "HEAD")
fi
RELEASE_TAG="${RELEASE_TAG:-$CURRENT_REF}"

case "$RELEASE_TAG" in
  p[0-9]*) TAG_PATTERN='p[0-9]*'; FALLBACK_TAG_PATTERN='v[0-9]*' ;;
  v[0-9]*) TAG_PATTERN='v[0-9]*'; FALLBACK_TAG_PATTERN='p[0-9]*' ;;
  *) TAG_PATTERN='[pv][0-9]*'; FALLBACK_TAG_PATTERN='' ;;
esac

# When a workflow runs on a release tag, exclude that tag itself. Otherwise a
# describe/tag lookup would produce TAG..HEAD with no commits.
CURRENT_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null || true)
if [ -n "$CURRENT_TAG" ]; then
  TAG_BASE=$(git rev-parse "$CURRENT_TAG^" 2>/dev/null || true)
else
  TAG_BASE=HEAD
fi

LAST_TAG=$(git tag --merged "$TAG_BASE" --list "$TAG_PATTERN" --sort=-version:refname | head -n 1)
if [ -z "$LAST_TAG" ] && [ -n "$FALLBACK_TAG_PATTERN" ]; then
  LAST_TAG=$(git tag --merged "$TAG_BASE" --list "$FALLBACK_TAG_PATTERN" --sort=-version:refname | head -n 1)
fi

if [ -z "$LAST_TAG" ]; then
  # No tags found, get all commits
  RANGE="HEAD"
  RANGE_DESC="initial release"
else
  # Get commits since the last tag
  RANGE="${LAST_TAG}..HEAD"
  RANGE_DESC="$LAST_TAG..HEAD"
fi

echo "📝 Generating changelog for: $RANGE_DESC" >&2

# Keep the release page readable like Lumi: omit CI/build noise, preserve
# scoped Conventional Commits, deduplicate repeated subjects, and cap the list.
CHANGE_COMMITS=$(git log "$RANGE" --no-merges --pretty=format:'- %s' 2>/dev/null \
  | grep -Ev '^- (ci|chore|build|style|test)(\([^)]*\))?!?:' \
  | grep -Ev '^- 👷 CI:' \
  | sort -u \
  | sed -n '1,20p' || true)

REPO_NAME="${GITHUB_REPOSITORY:-CofficLab/Cisum}"
if [ -z "$LAST_TAG" ]; then
  NOTES="## Release ${RELEASE_TAG}\n\nInitial release"
else
  if [ -z "$CHANGE_COMMITS" ]; then
    CHANGE_COMMITS="- Maintenance and stability improvements"
  fi
  NOTES="## Release ${RELEASE_TAG}\n\n### Changes since ${LAST_TAG}\n\n${CHANGE_COMMITS}\n\n---\n\n**Full Changelog**: https://github.com/${REPO_NAME}/compare/${LAST_TAG}...${RELEASE_TAG}"
fi

printf '%b\n' "$NOTES" > "$OUTPUT_FILE"

echo "✅ Changelog generated: $OUTPUT_FILE" >&2
