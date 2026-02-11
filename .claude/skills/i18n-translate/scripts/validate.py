#!/usr/bin/env python3
"""验证 Localizable.xcstrings 文件的 JSON 格式"""

import json
import sys

def validate(file_path: str) -> bool:
    """验证 JSON 格式是否正确"""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        # 检查基本结构
        if "strings" not in data:
            print("❌ 错误: 缺少 'strings' 字段")
            return False

        strings_data = data["strings"]
        print(f"✅ JSON 格式正确")
        print(f"   总条目数: {len(strings_data)}")

        # 统计翻译情况
        has_zh_hans = 0
        has_zh_hk = 0
        missing_zh_hans = 0
        missing_zh_hk = 0

        for key, entry in strings_data.items():
            if "localizations" not in entry:
                continue
            locs = entry["localizations"]
            if "zh-Hans" in locs:
                has_zh_hans += 1
            else:
                missing_zh_hans += 1
            if "zh-HK" in locs:
                has_zh_hk += 1
            else:
                missing_zh_hk += 1

        print(f"   zh-Hans: {has_zh_hans} 个已有, {missing_zh_hans} 个缺失")
        print(f"   zh-HK: {has_zh_hk} 个已有, {missing_zh_hk} 个缺失")

        return True

    except json.JSONDecodeError as e:
        print(f"❌ JSON 格式错误: {e}")
        return False
    except Exception as e:
        print(f"❌ 错误: {e}")
        return False

if __name__ == "__main__":
    file_path = sys.argv[1] if len(sys.argv) > 1 else "Localizable.xcstrings"
    result = validate(file_path)
    sys.exit(0 if result else 1)
