#!/usr/bin/env python3
"""批量处理项目中所有 .xcstrings 文件"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

# 获取脚本所在目录
SCRIPT_DIR = Path(__file__).parent


def find_xcstrings_files(root_dir: str = ".") -> list[Path]:
    """查找所有 .xcstrings 文件"""
    root = Path(root_dir)
    files = list(root.rglob("*.xcstrings"))
    # 过滤掉隐藏目录中的文件
    return [f for f in files if not any(p.startswith(".") for p in f.parts)]


def run_command(cmd: list[str], file_path: Path) -> bool:
    """运行命令并返回是否成功"""
    script_path = SCRIPT_DIR / cmd[0]
    full_cmd = [sys.executable, str(script_path)] + cmd[1:] + [str(file_path)]

    try:
        result = subprocess.run(
            full_cmd,
            capture_output=True,
            text=True,
            check=False
        )
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        return result.returncode == 0
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        return False


def clean_all(root_dir: str = ".") -> dict[str, int]:
    """清理所有文件中的过期条目"""
    files = find_xcstrings_files(root_dir)
    results = {}

    for file_path in files:
        print(f"\n=== 清理 {file_path} ===")
        cmd = ["clean_stale.py"]
        if run_command(cmd, file_path):
            # 重新读取文件获取删除数量
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                results[str(file_path)] = len(data.get("strings", {}))
            except:
                results[str(file_path)] = 0

    return results


def check_all(root_dir: str = ".") -> dict[str, dict]:
    """检查所有文件的缺失翻译"""
    files = find_xcstrings_files(root_dir)
    results = {}

    for file_path in files:
        print(f"\n=== 检查 {file_path} ===")
        cmd = ["check_missing.py"]
        run_command(cmd, file_path)

    return results


def validate_all(root_dir: str = ".") -> dict[str, bool]:
    """验证所有文件的格式"""
    files = find_xcstrings_files(root_dir)
    results = {}

    for file_path in files:
        print(f"\n=== 验证 {file_path} ===")
        cmd = ["validate.py"]
        results[str(file_path)] = run_command(cmd, file_path)

    return results


def list_files(root_dir: str = ".") -> list[Path]:
    """列出所有 .xcstrings 文件"""
    files = find_xcstrings_files(root_dir)
    print(f"找到 {len(files)} 个 .xcstrings 文件:")
    for f in files:
        print(f"  - {f}")
    return files


def main():
    parser = argparse.ArgumentParser(description="批量处理 .xcstrings 文件")
    parser.add_argument(
        "action",
        choices=["list", "clean", "check", "validate"],
        help="操作类型: list(列出文件), clean(清理过期), check(检查缺失), validate(验证格式)"
    )
    parser.add_argument(
        "--dir",
        "-d",
        default=".",
        help="项目根目录 (默认: 当前目录)"
    )

    args = parser.parse_args()

    if args.action == "list":
        list_files(args.dir)
    elif args.action == "clean":
        clean_all(args.dir)
    elif args.action == "check":
        check_all(args.dir)
    elif args.action == "validate":
        validate_all(args.dir)


if __name__ == "__main__":
    main()
