#!/usr/bin/env python3
"""删除 Localizable.xcstrings 中所有标记为 stale 的条目"""

import json
import sys

def clean_stale(file_path: str) -> int:
    """删除 stale 条目，返回删除的数量"""
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    strings_data = data.get("strings", {})
    stale_keys = []

    for key, entry in strings_data.items():
        if entry.get("extractionState") == "stale":
            stale_keys.append(key)

    for key in stale_keys:
        del strings_data[key]

    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    return len(stale_keys)

if __name__ == "__main__":
    file_path = sys.argv[1] if len(sys.argv) > 1 else "Localizable.xcstrings"
    count = clean_stale(file_path)
    print(f"已删除 {count} 个过期条目")
