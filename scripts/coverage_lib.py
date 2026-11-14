#!/usr/bin/env python3
"""覆盖率 JSON 解析与汇总报告生成。

`collect-coverage.sh` 对每个包调用 llvm-cov export -format=text，产出 JSON；
本脚本负责从中提取行覆盖率并生成 Markdown 汇总报告。

注意 llvm-cov text(JSON) 的字段含义：
  - `summary.lines.count`   = 该文件的**总**可执行行数
  - `summary.lines.covered` = 其中**已覆盖**行数
直接用 `percent` 最稳妥，此处显式换算以便累加。
"""

import json
import sys
from pathlib import Path


def load_coverage(path: Path) -> dict:
    with path.open() as f:
        return json.load(f)


def iter_source_files(data: dict, pkg: str = None):
    """只遍历本包 Packages/<pkg>/Sources/ 下的源码。

    必须排除：
      - Tests/ 与构建产物（覆盖率目标是被测代码，不是测试代码）
      - 其它包的源码（`.build/checkouts/` 下依赖包、以及别的 Packages/*/Sources）。
        它们同样带 /Sources/ 路径，但不属于本包，计入会把覆盖率算低。

    注意本项目插件包的 Sources/ 下**没有**包名包裹目录（源码直接放 Sources/），
    所以这里按路径前缀精确匹配，而不是要求 Sources/<PackageName>/。
    """
    if not pkg:
        return
    prefix = f"/Packages/{pkg}/Sources/"
    for file_data in data.get("data", []):
        for f in file_data.get("files", []):
            name = f.get("filename", "")
            if "/.build/" in name or "/Tests/" in name:
                continue
            if prefix not in name:
                continue
            yield f


def line_coverage(path: Path) -> str:
    """包级行覆盖率百分比字符串（仅统计本包 Sources/<包名>/ 下源码）。"""
    data = load_coverage(path)
    covered = total = 0
    for f in iter_source_files(data, pkg=path.stem):
        lines = f.get("summary", {}).get("lines", {})
        covered += lines.get("covered", 0)
        total += lines.get("count", 0)
    if total == 0:
        return "N/A"
    return f"{covered * 100.0 / total:.2f}"


def file_rows(data: dict, pkg: str):
    """产出 (相对路径, 行覆盖率%, 未覆盖行数)，仅本包源码，按覆盖率升序。"""
    rows = []
    for f in iter_source_files(data, pkg=pkg):
        name = f["filename"]
        rel = name.split("/Sources/", 1)[-1]
        lines = f.get("summary", {}).get("lines", {})
        total, cov = lines.get("count", 0), lines.get("covered", 0)
        if total == 0:
            continue
        rows.append((rel, cov * 100.0 / total, total - cov))
    rows.sort(key=lambda r: r[1])
    return rows


def report(results_path: Path, out) -> None:
    rows = []
    for raw in results_path.read_text().splitlines():
        parts = raw.split("\t")
        if len(parts) < 3:
            continue
        name, cov, status = parts[0], parts[1], parts[2]
        try:
            value = float(cov)
        except ValueError:
            value = -1.0
        rows.append((name, cov, status, value))

    ok = sorted([r for r in rows if r[3] >= 0], key=lambda r: r[3])

    out.write("## 单元测试覆盖率汇总\n\n")
    out.write(f"- 参与统计的包：{len(rows)}\n")
    out.write(f"- 成功产出覆盖率：{len(ok)}\n")
    if ok:
        avg = sum(r[3] for r in ok) / len(ok)
        out.write(f"- 平均行覆盖率：{avg:.2f}%\n\n")
    out.write("按行覆盖率升序（最需要补测的在前）：\n\n")
    out.write("| 包 | 行覆盖率 | 状态 |\n|---|---|---|\n")
    for name, cov, status, _ in rows:
        out.write(f"| {name} | {cov}% | {status} |\n")


def file_report(json_path: Path, out, limit: int = 30) -> None:
    """单包逐文件报告，突出未覆盖行数最多的文件。"""
    data = load_coverage(json_path)
    pkg = json_path.stem
    rows = file_rows(data, pkg)
    out.write(f"## {pkg} 覆盖率明细\n\n")
    if not rows:
        out.write("无 Sources/ 下覆盖率数据。\n")
        return
    avg = sum(r[1] for r in rows) / len(rows)
    out.write(f"- 文件数：{len(rows)} · 平均行覆盖率：{avg:.2f}%\n\n")
    out.write("| 文件 | 行覆盖率 | 未覆盖行数 |\n|---|---|---|\n")
    for rel, pct, missed in rows[:limit]:
        out.write(f"| {rel} | {pct:.2f}% | {missed} | \n")


def main() -> None:
    if len(sys.argv) < 3:
        print("用法: coverage_lib.py line-coverage <json> | report <results> | file-report <json>")
        sys.exit(1)
    mode, arg = sys.argv[1], Path(sys.argv[2])
    if mode == "line-coverage":
        print(line_coverage(arg))
    elif mode == "report":
        report(arg, sys.stdout)
    elif mode == "file-report":
        file_report(arg, sys.stdout)
    else:
        sys.exit(f"未知模式: {mode}")


if __name__ == "__main__":
    main()
