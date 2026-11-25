#!/usr/bin/env bash
set -euo pipefail

# 把随包内嵌的 mpv / FFmpeg 动态库复制进 App 的 Frameworks 目录。
#
# 这些库以 `@rpath/<name>.dylib` 形式解析依赖，因此必须与 App 一起签名，
# 并通过 `@executable_path/../Frameworks` 的 rpath 找到。

if [[ "${PLATFORM_NAME:-}" != "macosx" ]]; then
  echo "Skipping dylib copy for non-macOS platform (${PLATFORM_NAME:-unknown})"
  exit 0
fi
if [[ "${CODE_SIGNING_ALLOWED:-YES}" == "NO" ]]; then
  echo "Skipping dylib copy/sign because CODE_SIGNING_ALLOWED=NO"
  exit 0
fi

FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
DYLIBS_DIR="${SRCROOT}/Packages/MPVKit/Sources/MPVC/dylibs"
SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:-}}"
APP_MIN_OS="${MACOSX_DEPLOYMENT_TARGET:-}"

mkdir -p "${FRAMEWORKS_DIR}"

if [[ ! -d "${DYLIBS_DIR}" ]]; then
  echo "error: vendored dylibs directory not found at ${DYLIBS_DIR}" >&2
  exit 1
fi

shopt -s nullglob
dylibs=("${DYLIBS_DIR}"/*.dylib)
shopt -u nullglob
if [[ "${#dylibs[@]}" -eq 0 ]]; then
  echo "error: no vendored dylibs found at ${DYLIBS_DIR}" >&2
  exit 1
fi

for dylib in "${dylibs[@]}"; do
  cp -p "${dylib}" "${FRAMEWORKS_DIR}/"
done
echo "Copied ${#dylibs[@]} vendored dylibs to ${FRAMEWORKS_DIR}"

CHECK_SCRIPT="${SRCROOT}/scripts/check-vendored-macos-dylibs.sh"
if [[ -x "${CHECK_SCRIPT}" ]]; then
  "${CHECK_SCRIPT}" "${FRAMEWORKS_DIR}"
else
  echo "error: missing vendored dylib self-containment checker at ${CHECK_SCRIPT}" >&2
  exit 1
fi

# hardened runtime 下 LuaJIT 生成的机器码会被 AMFI 杀进程，随包版本必须关闭 JIT，
# 由 scripts/build-luajit-nojit.sh 生成。
for luajit in "${FRAMEWORKS_DIR}"/libluajit-*.dylib; do
  if strings -a "${luajit}" | grep -q 'sizemcode'; then
    echo "error: $(basename "${luajit}") was built with JIT enabled and will be killed by the hardened runtime" >&2
    echo "error: rebuild it via scripts/build-luajit-nojit.sh" >&2
    exit 1
  fi
done

if [[ -n "${APP_MIN_OS}" ]] && command -v vtool >/dev/null 2>&1; then
  for dylib in "${FRAMEWORKS_DIR}"/*.dylib; do
    dylib_min_os="$(vtool -show-build "${dylib}" | awk '/platform MACOS/{in_macos=1} in_macos && /minos/{print $2; exit}')"
    if [[ -n "${dylib_min_os}" ]] && [[ "${dylib_min_os}" != "${APP_MIN_OS}" ]]; then
      echo "warning: $(basename "${dylib}") requires macOS ${dylib_min_os}, app deployment target is ${APP_MIN_OS}" >&2
    fi
  done
fi

if [[ -z "${SIGN_IDENTITY}" ]]; then
  if [[ "${CODE_SIGNING_REQUIRED:-NO}" == "YES" ]]; then
    echo "error: no code signing identity available for vendored dylibs" >&2
    exit 1
  fi
  echo "warning: no code signing identity available; vendored dylibs are left unsigned"
  exit 0
fi

for dylib in "${FRAMEWORKS_DIR}"/*.dylib; do
  xattr -cr "${dylib}" || true
  codesign --force --sign "${SIGN_IDENTITY}" --options runtime --timestamp=none "${dylib}"
  codesign --verify --strict "${dylib}"
done
