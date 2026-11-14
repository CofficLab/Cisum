#!/bin/bash
# 收集各 SPM 包的单元测试覆盖率。
#
# 用法：
#   scripts/collect-coverage.sh              # 汇总全部有代码的包
#   scripts/collect-coverage.sh MagicKit     # 只跑指定包
#
# 输出：
#   temp/coverage/report.md    汇总报告（按行覆盖率升序，未覆盖点最多的在前）
#   temp/coverage/<包名>.json  llvm-cov 导出的逐文件明细
#   temp/coverage/<包名>.profdata / .xctest 暂存在各包 .build 下

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGS_DIR="$ROOT/Packages"
OUT_DIR="$ROOT/temp/coverage"
PROF_REL=".build/out/Products/Debug/codecov/default.profdata"
# swift test 的产物落在自定义 scratch path（见 Package 工具链配置），不是默认 .build/debug
BIN_REL=".build/out/Products/Debug"

mkdir -p "$OUT_DIR"
# 结果累积文件；每次运行前清空，保证报告只反映本次结果
RESULTS="$OUT_DIR/.results"
rm -f "$RESULTS"

PKGS=()

log() { printf '%s\n' "$*"; }

# 收集待跑包列表：只看有 Package.swift 且 Sources 下确有 Swift 源码的包
collect_packages() {
    local d name
    for d in "$PKGS_DIR"/*/; do
        name="$(basename "$d")"
        [ -f "$d/Package.swift" ] || continue
        [ -n "$(find "$d/Sources" -name '*.swift' -print -quit 2>/dev/null)" ] || continue
        PKGS+=("$name")
    done
}

# 单包：跑测试 + 导出覆盖率
# 覆盖率为 0 视为失败信号，记入 failed 而非 skipped，因为 0% 说明测试未真正触达代码
run_package() {
    local name="$1"
    local dir="$PKGS_DIR/$name"
    local log_file="$OUT_DIR/$name.log"
    local prof="$dir/$PROF_REL"
    local prof_dir="$dir/.build/out/Products/Debug/codecov"
    local bin_dir="$dir/$BIN_REL"
    local status="ok"

    # 只清覆盖率产物，不能删整个 bin 目录，否则连编好的 xctest 一起丢失
    rm -f "$prof"
    rm -f "$prof_dir"/*.profraw
    if ( cd "$dir" && swift test --enable-code-coverage ) >"$log_file" 2>&1; then
        log "  ✓ $name"
    else
        log "  ✗ $name  → $log_file"
        status="failed"
    fi

    local xctest_bin
    xctest_bin="$(find "$bin_dir" -maxdepth 1 -name '*.xctest' 2>/dev/null | head -1)"
    if [ -z "$xctest_bin" ]; then
        log "    (无 .xctest 产物，跳过报告)"
        printf '%s\t%s\t%s\n' "$name" "N/A" "$status" >>"$RESULTS"
        return
    fi

    # 测试失败时 swift test 可能不合成 default.profdata。
    # 此时自行把 .profraw 合并成 .profdata —— 直接喂 .profraw 给 llvm-cov 会报 bad magic。
    if [ ! -f "$prof" ]; then
        local raw merged="$prof_dir/default.profdata"
        raw="$(find "$prof_dir" -maxdepth 1 -name '*.profraw' 2>/dev/null | head -1)"
        if [ -n "$raw" ]; then
            xcrun llvm-profdata merge -sparse "$prof_dir"/*.profraw -o "$merged" 2>>"$log_file"
            prof="$merged"
        fi
    fi
    if [ ! -f "$prof" ]; then
        log "    (无覆盖率数据)"
        printf '%s\t%s\t%s\n' "$name" "N/A" "$status" >>"$RESULTS"
        return
    fi

    local test_bin="$xctest_bin/Contents/MacOS/$(basename "$xctest_bin" .xctest)"
    if ! xcrun llvm-cov export -format=text \
        -instr-profile="$prof" "$test_bin" >"$OUT_DIR/$name.json" 2>>"$log_file"; then
        log "    (llvm-cov export 失败)"
        printf '%s\t%s\t%s\n' "$name" "N/A" "$status" >>"$RESULTS"
        return
    fi

    local line_cov
    line_cov="$(python3 "$ROOT/scripts/coverage_lib.py" line-coverage "$OUT_DIR/$name.json" 2>/dev/null || echo NA)"
    printf '%s\t%s\t%s\n' "$name" "$line_cov" "$status" >>"$RESULTS"
}

write_report() {
    python3 "$ROOT/scripts/coverage_lib.py" report "$RESULTS" >"$OUT_DIR/report.md"
    log ""
    log "报告：$OUT_DIR/report.md"
}

main() {
    PKGS=()
    collect_packages

    if [ $# -gt 0 ]; then
        PKGS=("$@")
    fi

    log "共 ${#PKGS[@]} 个包"
    local p
    for p in "${PKGS[@]}"; do
        run_package "$p"
    done

    write_report
}

main "$@"
