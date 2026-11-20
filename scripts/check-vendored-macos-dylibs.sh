#!/usr/bin/env bash
set -euo pipefail

# 检查内嵌的 macOS 动态库是否自包含：
# - 不允许指向 App 之外的绝对路径依赖；
# - 不允许存在无法在随包目录中解析到的 @rpath 依赖。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$#" -gt 0 ]]; then
  DYLIB_DIRS=("$@")
else
  DYLIB_DIRS=(
    "${ROOT_DIR}/Packages/MPVKit/Sources/MPVC/dylibs"
  )
fi

for dir in "${DYLIB_DIRS[@]}"; do
  [[ -d "${dir}" ]] || { echo "error: missing dylib directory: ${dir}" >&2; exit 1; }
done

resolve_name() {
  local requested="$1"
  local stem="${requested%.dylib}"
  local dylib
  while IFS= read -r -d '' dylib; do
    [[ "$(basename "${dylib}")" == "${requested}" ]] && return 0
  done < <(find "${DYLIB_DIRS[@]}" -maxdepth 1 -type f -name '*.dylib' -print0)
  while IFS= read -r -d '' dylib; do
    [[ "$(basename "${dylib}")" == "${stem}".*.dylib ]] && return 0
  done < <(find "${DYLIB_DIRS[@]}" -maxdepth 1 -type f -name '*.dylib' -print0)
  return 1
}

failures=0
while IFS= read -r -d '' dylib; do
  while IFS= read -r dependency; do
    [[ "${dependency}" =~ ^/|^@rpath/ ]] || continue
    case "${dependency}" in
      /usr/lib/*|/System/*) continue ;;
    esac
    dependency_name="$(basename "${dependency}")"
    if [[ "${dependency}" == /* || ! "${dependency}" == @rpath/* ]]; then
      echo "error: external absolute dependency: ${dylib}: ${dependency}" >&2
      failures=$((failures + 1))
    elif ! resolve_name "${dependency_name}"; then
      echo "error: unresolved @rpath dependency: ${dylib}: ${dependency}" >&2
      failures=$((failures + 1))
    fi
  done < <(otool -L "${dylib}" | awk 'NR > 1 {print $1}')
done < <(find "${DYLIB_DIRS[@]}" -maxdepth 1 -type f -name '*.dylib' -print0)

if (( failures > 0 )); then
  echo "Vendored dylib self-containment check failed (${failures} issue(s))" >&2
  exit 1
fi

echo "Vendored dylib self-containment check passed"
