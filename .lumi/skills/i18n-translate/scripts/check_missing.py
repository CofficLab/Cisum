#!/usr/bin/env python3
"""检查 Localizable.xcstrings 中缺失的翻译"""

import json
import sys

def check_missing(file_path: str):
    """检查并输出缺失的翻译"""
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    strings_data = data.get("strings", {})

    missing_zh_hans = []
    missing_zh_hk = []
    empty_localizations = []

    for key, entry in strings_data.items():
        if "localizations" not in entry:
            empty_localizations.append(key)
            continue
        locs = entry["localizations"]
        if "zh-Hans" not in locs:
            missing_zh_hans.append(key)
        if "zh-HK" not in locs:
            missing_zh_hk.append(key)

    print(f"总条目数: {len(strings_data)}")
    print(f"缺少 localizations: {len(empty_localizations)}")
    print(f"缺少 zh-Hans: {len(missing_zh_hans)}")
    print(f"缺少 zh-HK: {len(missing_zh_hk)}")

    if empty_localizations:
        print("\n缺少 localizations 的条目:")
        for k in empty_localizations[:10]:
            print(f"  - {repr(k)}")

    if missing_zh_hans:
        print("\n缺少 zh-Hans 的条目:")
        for k in missing_zh_hans[:10]:
            print(f"  - {repr(k)}")

    if missing_zh_hk:
        print("\n缺少 zh-HK 的条目:")
        for k in missing_zh_hk[:10]:
            print(f"  - {repr(k)}")

    return missing_zh_hans, missing_zh_hk, empty_localizations

if __name__ == "__main__":
    file_path = sys.argv[1] if len(sys.argv) > 1 else "Localizable.xcstrings"
    check_missing(file_path)
