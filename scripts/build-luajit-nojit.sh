#!/usr/bin/env bash
set -euo pipefail

# 重新生成内嵌的 LuaJIT，构建时关闭 JIT。
#
# App Store / TestFlight 产物体启用 hardened runtime，LuaJIT 在运行期生成的机器码
# 会被 AMFI 判为非法页并强杀进程（表现为系统弹窗“Cisum 已损坏，无法打开”）。
# mpv 初始化时必然通过 Lua 加载内置脚本（stats/osc），进程内无法用 mpv 选项规避，
# 因此随包的 LuaJIT 必须以 LUAJIT_DISABLE_JIT 编译，脚本改为解释执行。
#
# 用法：scripts/build-luajit-nojit.sh [输出目录]
# 默认输出到 Packages/MPVKit/Sources/MPVC/dylibs。签名由构建阶段脚本统一处理。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${ROOT_DIR}/Packages/MPVKit/Sources/MPVC/dylibs}"

LUAJIT_COMMIT="2460b3ff93a1c955de3d62cfc825de7d68dc272e"
LUAJIT_SHA256="5c52d06876d86aa199f9b8cdc65f6f9ac086fdfa8a4489ebf8dc4516e194550b"
DYLIB_NAME="libluajit-5.1.2.1.1784580905.dylib"

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${BUILD_DIR}"' EXIT

echo "==> fetching LuaJIT ${LUAJIT_COMMIT:0:12}"
curl -fsSL -o "${BUILD_DIR}/luajit.tar.gz" \
  "https://codeload.github.com/LuaJIT/LuaJIT/tar.gz/${LUAJIT_COMMIT}"
echo "${LUAJIT_SHA256}  ${BUILD_DIR}/luajit.tar.gz" | shasum -a 256 -c -
tar xzf "${BUILD_DIR}/luajit.tar.gz" -C "${BUILD_DIR}"

echo "==> building without JIT"
(
  cd "${BUILD_DIR}/LuaJIT-${LUAJIT_COMMIT}"
  MACOSX_DEPLOYMENT_TARGET=15.0 make -j"$(sysctl -n hw.ncpu)" amalg \
    XCFLAGS="-DLUAJIT_DISABLE_JIT" Q= E=@:
)

mkdir -p "${OUT_DIR}"
cp "${BUILD_DIR}/LuaJIT-${LUAJIT_COMMIT}/src/libluajit.so" "${OUT_DIR}/${DYLIB_NAME}"
install_name_tool -id "@rpath/${DYLIB_NAME}" "${OUT_DIR}/${DYLIB_NAME}"
xattr -cr "${OUT_DIR}/${DYLIB_NAME}"

echo "==> wrote ${OUT_DIR}/${DYLIB_NAME}"
otool -D "${OUT_DIR}/${DYLIB_NAME}" | tail -1