#!/bin/bash
#
# generate-changelog.sh - Generate categorized changelog from commits
#
# This script analyzes git commits since the last tag and generates
# a categorized changelog following Conventional Commits format.
# Categories with no changes are omitted.
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

# Get the most recent tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

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

# Helper function to add a category section
# Usage: add_category <title> <commits_var_name>
add_category() {
  local title="$1"
  local commits="$2"

  if [ -n "$commits" ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "$title" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "$commits" | awk '!seen[$0]++ {print "- " $0}' >> "$OUTPUT_FILE"
  fi
}

# Initialize output file
> "$OUTPUT_FILE"

# Get all commits
FEAT_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^feat:" 2>/dev/null | grep -v "feat!" || echo "")
FIX_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^fix:" 2>/dev/null | grep -v "fix!" || echo "")
CHORE_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^chore:" 2>/dev/null || echo "")
REFACTOR_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^refactor:" 2>/dev/null | grep -v "refactor!" || echo "")
DOCS_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^docs:" 2>/dev/null || echo "")
BREAKING_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^feat!:\|^fix!:\|^refactor!:\|BREAKING CHANGE:" 2>/dev/null || echo "")

# Add each category only if it has commits
add_category "## ✨ Features" "$FEAT_COMMITS"
add_category "## 🐛 Bug Fixes" "$FIX_COMMITS"
add_category "## 🔧 Maintenance" "$CHORE_COMMITS"
add_category "## ♻️ Refactoring" "$REFACTOR_COMMITS"
add_category "## 📚 Documentation" "$DOCS_COMMITS"
add_category "## 💥 Breaking Changes" "$BREAKING_COMMITS"

# Add comparison link if there's a previous tag
if [ -n "$LAST_TAG" ]; then
    REPO_NAME="${GITHUB_REPOSITORY:-CofficLab/Cisum_SwiftUI}"
    CURRENT_REF="${GITHUB_REF_NAME:-pre}"

    cat >> "$OUTPUT_FILE" << EOF

---

**Full Changelog**: https://github.com/${REPO_NAME}/compare/${LAST_TAG}...${CURRENT_REF}
EOF
fi

echo "✅ Changelog generated: $OUTPUT_FILE" >&2
