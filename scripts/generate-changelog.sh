#!/bin/bash
#
# generate-changelog.sh - Generate categorized changelog from commits
#
# This script analyzes git commits since the last tag and generates
# a categorized changelog following Conventional Commits format.
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

# Start writing to output file
cat > "$OUTPUT_FILE" << 'EOF'
## ✨ Features

EOF

# Get feat commits and deduplicate by message
FEAT_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^feat:" 2>/dev/null || echo "")
if [ -z "$FEAT_COMMITS" ]; then
  echo "No new features" >> "$OUTPUT_FILE"
else
  # Deduplicate while preserving order (first occurrence kept)
  echo "$FEAT_COMMITS" | awk '!seen[$0]++ {print "- " $0}' >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" << 'EOF'


## 🐛 Bug Fixes

EOF

# Get fix commits and deduplicate by message
FIX_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^fix:" 2>/dev/null || echo "")
if [ -z "$FIX_COMMITS" ]; then
  echo "No bug fixes" >> "$OUTPUT_FILE"
else
  # Deduplicate while preserving order (first occurrence kept)
  echo "$FIX_COMMITS" | awk '!seen[$0]++ {print "- " $0}' >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" << 'EOF'


## 🔧 Maintenance

EOF

# Get chore commits and deduplicate by message
CHORE_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^chore:" 2>/dev/null || echo "")
if [ -z "$CHORE_COMMITS" ]; then
  echo "No maintenance updates" >> "$OUTPUT_FILE"
else
  # Deduplicate while preserving order (first occurrence kept)
  echo "$CHORE_COMMITS" | awk '!seen[$0]++ {print "- " $0}' >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" << 'EOF'


## ♻️ Refactoring

EOF

# Get refactor commits and deduplicate by message
REFACTOR_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^refactor:" 2>/dev/null || echo "")
if [ -z "$REFACTOR_COMMITS" ]; then
  echo "No refactoring changes" >> "$OUTPUT_FILE"
else
  # Deduplicate while preserving order (first occurrence kept)
  echo "$REFACTOR_COMMITS" | awk '!seen[$0]++ {print "- " $0}' >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" << 'EOF'


## 📚 Documentation

EOF

# Get docs commits and deduplicate by message
DOCS_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^docs:" 2>/dev/null || echo "")
if [ -z "$DOCS_COMMITS" ]; then
  echo "No documentation updates" >> "$OUTPUT_FILE"
else
  # Deduplicate while preserving order (first occurrence kept)
  echo "$DOCS_COMMITS" | awk '!seen[$0]++ {print "- " $0}' >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" << 'EOF'


## 💥 Breaking Changes

EOF

# Get breaking changes (feat!, fix!, BREAKING CHANGE) and deduplicate by message
BREAKING_COMMITS=$(git log $RANGE --pretty=format:'%s' --grep="^feat!:\|^fix!:\|^refactor!:\|BREAKING CHANGE:" 2>/dev/null || echo "")
if [ -z "$BREAKING_COMMITS" ]; then
  echo "No breaking changes" >> "$OUTPUT_FILE"
else
  # Deduplicate while preserving order (first occurrence kept)
  echo "$BREAKING_COMMITS" | awk '!seen[$0]++ {print "- " $0}' >> "$OUTPUT_FILE"
fi

# Add comparison link if there's a previous tag
if [ -n "$LAST_TAG" ]; then
    REPO_NAME="${GITHUB_REPOSITORY:-your-org/your-repo}"
    CURRENT_REF="${GITHUB_REF_NAME:-main}"

    cat >> "$OUTPUT_FILE" << EOF

---

**Full Changelog**: https://github.com/${REPO_NAME}/compare/${LAST_TAG}...${CURRENT_REF}
EOF
fi

echo "✅ Changelog generated: $OUTPUT_FILE" >&2
