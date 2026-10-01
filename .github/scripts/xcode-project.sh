#!/bin/bash
#
# xcode-project.sh - Locate and edit Xcode project version settings
#
# Xcode 27.2 replaces the property-list project.pbxproj with a JSON
# project.xcproj file. These helpers resolve whichever project file the
# repository tracks, then read or write version settings in place so the
# surrounding formatting stays untouched and Xcode diffs remain readable.
#
# Source this file; do not execute it directly.
#
#   source "$SCRIPT_DIR/xcode-project.sh"
#   PROJECT_FILE=$(xcode_project_file "$(pwd)")
#   xcode_project_setting "$PROJECT_FILE" MARKETING_VERSION
#   xcode_project_set_setting "$PROJECT_FILE" MARKETING_VERSION 4.2.0 4.3.0
#
# Reading a setting returns the first occurrence, which is the main app
# target. Writing only rewrites values that still equal the expected old
# value, so targets that intentionally keep a different version (for example
# the UI test bundle) are preserved.

# Resolve the Xcode project configuration file, preferring project.xcproj.
# Prints the path on success and returns 1 when neither format exists.
xcode_project_file() {
  local root="${1:-$(pwd)}"
  local name candidate
  local prune=(-not -path "*/.build/*" -not -path "*/.git/*")

  for name in project.xcproj project.pbxproj; do
    candidate=$(find "$root" -type f -name "$name" "${prune[@]}" 2>/dev/null \
      | head -n 1 || true)
    if [ -n "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

# Print the value of a build setting, or return 1 when it is not present.
xcode_project_setting() {
  local file="$1"
  local setting="$2"
  local value=""

  if [ ! -f "$file" ]; then
    return 1
  fi

  case "$file" in
    *.xcproj)
      value=$(grep -m 1 -oE "\"${setting}\": \"[^\"]*\"" "$file" 2>/dev/null \
        | sed -E 's/.*: "(.*)"/\1/' || true)
      ;;
    *)
      value=$(grep -m 1 -oE "${setting} = [^;]*" "$file" 2>/dev/null \
        | sed -E 's/.*=[[:space:]]*//; s/^"//; s/"$//' || true)
      ;;
  esac

  if [ -z "$value" ]; then
    return 1
  fi

  printf '%s\n' "$value"
}

# Count how many entries currently hold the given value.
xcode_project_setting_count() {
  local file="$1"
  local setting="$2"
  local value="$3"
  local count=0

  [ -f "$file" ] || { printf '0\n'; return 0; }

  case "$file" in
    *.xcproj)
      count=$(grep -c "\"${setting}\": \"${value}\"" "$file" 2>/dev/null || true)
      ;;
    *)
      count=$(grep -c "${setting} = ${value};" "$file" 2>/dev/null || true)
      ;;
  esac

  printf '%s\n' "${count:-0}"
}

# Replace every occurrence of a setting that currently holds <old> with <new>.
xcode_project_set_setting() {
  local file="$1"
  local setting="$2"
  local old="$3"
  local new="$4"
  local escaped

  # Version strings contain dots; escape them so they match literally.
  escaped=$(printf '%s' "$old" | sed 's/\./\\./g')

  case "$file" in
    *.xcproj)
      sed -i '' -E "s/(\"${setting}\": )\"${escaped}\"/\1\"${new}\"/g" "$file"
      ;;
    *)
      sed -i '' -E "s/(${setting} = )${escaped};/\1${new};/g" "$file"
      ;;
  esac
}
