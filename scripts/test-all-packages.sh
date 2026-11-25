#!/bin/bash
# 遍历 Packages/ 下所有含源码的包，逐一运行 swift test 并汇总结果。
# 用法：scripts/test-all-packages.sh
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

PASS=()
FAIL=()
SKIP=()
FLAKY=()

# 测试进程被信号杀死时，输出里通常没有栈，把系统崩溃报告一起打出来。
# 只收本次测试开始之后生成的报告（stamp 的 mtime 是运行起点），
# 否则会把不相关的历史崩溃一起打出来，淹没真正的栈。
dump_crash_reports() {
    local pkg="$1" stamp="$2"
    local report

    # ReportCrash 是异步落盘的：进程死后往往还要几秒报告才出现，先等一会儿。
    local waited=0
    while [ "$waited" -lt 15 ]; do
        find "${HOME}/Library/Logs/DiagnosticReports" -maxdepth 1 -name '*.ips' -newer "${stamp}" 2>/dev/null | grep -q . && break
        sleep 1
        waited=$((waited + 1))
    done

    for report in $(find "${HOME}/Library/Logs/DiagnosticReports" -maxdepth 1 -name '*.ips' -newer "${stamp}" 2>/dev/null | head -5); do
        if grep -qE "swiftpm-testing-helper|xctest-|PackageTests" "${report}"; then
            echo "::group::💥 ${pkg} 崩溃报告 $(basename "${report}")"
            head -c 200000 "${report}"
            echo
            echo "::endgroup::"
        fi
    done
}

report_failure() {
    local pkg="$1" title="$2" output="$3" exit_code="$4" stamp="$5"
    # 输出完整尾部：只过滤报错行会丢掉崩溃栈，signal 11 这类失败必须看完整输出。
    echo "::group::❌ ${pkg} ${title} (exit ${exit_code})"
    echo "$output" | tail -80
    echo "::endgroup::"
    dump_crash_reports "$pkg" "$stamp"
}

test_count() {
    local line
    line=$(echo "$1" | grep -oE "Test run with [0-9]+ tests? in [0-9]+ suites? passed" | tail -1)
    echo "$line" | grep -oE "[0-9]+" | head -1
}

# 如果没有 Packages 目录或为空，直接跳过
if [ ! -d "Packages" ] || [ -z "$(ls -A Packages 2>/dev/null)" ]; then
    echo "⏭️  没有 Packages 目录或为空，跳过包测试"
    exit 0
fi

for dir in Packages/*/; do
    # 如果 glob 没匹配到任何目录，跳过
    [ -d "$dir" ] || continue
    pkg="$(basename "$dir")"

    # 跳过空目录（只剩 .swiftpm 残留）
    if [ ! -d "$dir/Sources" ] || [ -z "$(find "$dir/Sources" -name '*.swift' 2>/dev/null | head -1)" ]; then
        SKIP+=("$pkg")
        continue
    fi

    if [ ! -d "$dir/Tests" ]; then
        SKIP+=("$pkg (无测试)")
        continue
    fi

    # stamp 的 mtime 作为「本次测试开始」的界线，用于筛出本次的崩溃报告。
    stamp="$(mktemp "${TMPDIR:-/tmp}/cisum-test.XXXXXX")"
    output=$(cd "$dir" && swift test 2>&1)
    exit_code=$?

    if [ "${exit_code}" -eq 0 ]; then
        rm -f "$stamp"
        PASS+=("$pkg: $(test_count "$output" | sed 's/^$/unknown/') tests")
        continue
    fi

    report_failure "$pkg" "详细错误" "$output" "${exit_code}" "$stamp"

    # 测试进程被信号杀死（而非断言或编译失败）时重试一次：这类失败是 runner
    # 上偶发的测试宿主崩溃，与用例逻辑无关，重试即可区分偶发与稳定复现。
    if echo "$output" | grep -q "exited with unexpected signal code"; then
        echo "::warning::${pkg} 测试进程被信号杀死，重试一次"
        output=$(cd "$dir" && swift test 2>&1)
        exit_code=$?
        if [ "${exit_code}" -eq 0 ]; then
            rm -f "$stamp"
            FLAKY+=("$pkg: 首次崩溃，重试通过")
            continue
        fi
        report_failure "$pkg" "重试仍失败" "$output" "${exit_code}" "$stamp"
    fi

    rm -f "$stamp"
    reason=$(echo "$output" | grep -E "error:|signal code|Expectation failed" | head -1)
    FAIL+=("$pkg: ${reason:-测试失败} (exit ${exit_code})")
done

echo "================ 测试结果 ================"
echo "✅ 通过 (${#PASS[@]})"
if [ ${#PASS[@]} -gt 0 ]; then
    for item in "${PASS[@]}"; do echo "   $item"; done
fi

if [ ${#FLAKY[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  偶发失败、重试通过 (${#FLAKY[@]})"
    for item in "${FLAKY[@]}"; do echo "   $item"; done
fi

if [ ${#FAIL[@]} -gt 0 ]; then
    echo ""
    echo "❌ 失败 (${#FAIL[@]})"
    for item in "${FAIL[@]}"; do echo "   $item"; done
fi

if [ ${#SKIP[@]} -gt 0 ]; then
    echo ""
    echo "⏭️  跳过 (${#SKIP[@]}): ${SKIP[*]}"
fi

[ ${#FAIL[@]} -eq 0 ]