#!/usr/bin/env python3
"""生成统一的产品 ID 集合。

`StoreConfig.productTier` 是「商品 ID → 订阅等级」的唯一真值源。
本脚本以根目录 `Products.storekit` 为结构基准，补全配置中缺失的 Cisum
订阅商品，输出到 `Packages/PluginStore/Resources/Products.storekit`。

两份配置必须一致：一份用于本地 Xcode 调试（scheme 引用），一份随包分发。
漂移的后果是付费链路静默断裂——商品能买到但没有 tier 映射，权益不到账。

用法：
    python3 scripts/sync-storekit-config.py [--check]

`--check` 只校验一致性并以非零退出码报错，不写文件（供 CI 使用）。
"""

import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Products.storekit"
TARGET = ROOT / "Packages" / "PluginStore" / "Resources" / "Products.storekit"

# StoreConfig.productTier 中授予 Pro 权益的商品 ID。
# 任何在 .storekit 里存在、但不在这里列出的 Cisum 订阅，都会因为缺少
# tier 映射而导致「买了不给权益」。
PRO_SUBSCRIPTION_IDS = [
    "com.yueyi.cisum.pro.monthly",
    "com.yueyi.cisum.monthly",
    "com.yueyi.cisum.pro.yearly",
    "com.yueyi.cisum.yearly",
    "com.yueyi.cisum.pro.annual",
    "com.yueyi.cisum.annual",
]

PRO_NON_RENEWING_IDS = [
    "com.yueyi.cisum.pro.month.1",
    "com.yueyi.cisum.pro.year.1",
    "com.yueyi.cisum.pro.day.7",
]


def make_subscription(product_id, group_id, internal_id, period, group_number, price):
    """构造一条自动续期订阅条目。"""
    return {
        "adHocOffers": [],
        "codeOffers": [],
        "displayPrice": price,
        "familyShareable": False,
        "groupNumber": group_number,
        "internalID": internal_id,
        "introductoryOffer": None,
        "localizations": [
            {"description": "", "displayName": "Pro", "locale": "en_US"},
            {"description": "", "displayName": "专业版", "locale": "zh_Hans"},
        ],
        "productID": product_id,
        "recurringSubscriptionPeriod": period,
        "referenceName": product_id,
        "subscriptionGroupID": group_id,
        "type": "RecurringSubscription",
        "winbackOffers": [],
    }


def make_non_renewing(product_id, internal_id, price):
    """构造一条非续期订阅条目。"""
    return {
        "displayPrice": price,
        "familyShareable": False,
        "internalID": internal_id,
        "localizations": [
            {"description": "", "displayName": "Pro", "locale": "en_US"},
            {"description": "", "displayName": "专业版", "locale": "zh_Hans"},
        ],
        "productID": product_id,
        "referenceName": product_id,
        "type": "NonRenewingSubscription",
    }


def collect_ids(config):
    """收集配置里的全部商品 ID。"""
    ids = set()
    for group in config.get("subscriptionGroups", []):
        for subscription in group.get("subscriptions", []):
            ids.add(subscription["productID"])
    for subscription in config.get("nonRenewingSubscriptions", []):
        ids.add(subscription["productID"])
    for product in config.get("products", []):
        ids.add(product["productID"])
    return ids


def build_unified():
    """以根目录配置为基准，补全 Cisum 订阅商品。"""
    config = json.loads(SOURCE.read_text())

    existing = collect_ids(config)

    # 补全自动续期订阅：取第一个订阅组，把缺失的 Cisum 商品加进去。
    groups = config.get("subscriptionGroups", [])
    if groups:
        group = groups[0]
        group_id = group["id"]
        next_number = max(
            (s.get("groupNumber", 0) for s in group.get("subscriptions", [])), default=0
        ) + 1
        internal_counter = 0x10000001
        for product_id in PRO_SUBSCRIPTION_IDS:
            if product_id in existing:
                continue
            period = "P1Y" if ("year" in product_id or "annual" in product_id) else "P1M"
            group.setdefault("subscriptions", []).append(
                make_subscription(
                    product_id,
                    group_id,
                    f"{internal_counter:08X}",
                    period,
                    next_number,
                    "20" if period == "P1Y" else "2",
                )
            )
            internal_counter += 1
            next_number += 1

    # 补全非续期订阅。
    internal_counter = 0x20000001
    for product_id in PRO_NON_RENEWING_IDS:
        if product_id in existing:
            continue
        price = "1" if "day" in product_id else ("79" if "year" in product_id else "1.99")
        config.setdefault("nonRenewingSubscriptions", []).append(
            make_non_renewing(product_id, f"{internal_counter:08X}", price)
        )
        internal_counter += 1

    return config


def check_consistency(config):
    """校验配置与 StoreConfig.productTier 的一致性。"""
    errors = []

    config_ids = collect_ids(config)
    # StoreConfig 里的商品 ID（解析源码，避免重复维护一份列表）。
    store_config = (ROOT / "Packages" / "ProviderStore" / "Sources" / "ProviderStore"
                    / "Models" / "StoreConfig.swift").read_text()
    import re
    mapped = set(re.findall(r'"([a-z0-9.]+)":\s*\.(?:none|pro|ultimate)', store_config))

    missing_mapping = sorted(config_ids - mapped)
    if missing_mapping:
        errors.append(
            "以下商品在 .storekit 里存在，但 StoreConfig 没有 tier 映射"
            "（购买后不会授予权益）：\n  " + "\n  ".join(missing_mapping)
        )

    missing_config = sorted(
        pid for pid in mapped
        if pid.startswith("com.yueyi.cisum") and pid not in config_ids
    )
    if missing_config:
        errors.append(
            "以下商品在 StoreConfig 里有映射，但 .storekit 里缺失"
            "（购买面板加载不出来）：\n  " + "\n  ".join(missing_config)
        )

    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="只校验，不写文件")
    args = parser.parse_args()

    unified = build_unified()

    errors = check_consistency(unified)
    if errors:
        print("❌ StoreKit 配置不一致：")
        for error in errors:
            print(error)
        return 1

    if args.check:
        print("✅ StoreKit 配置与 StoreConfig 一致")
        return 0

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(json.dumps(unified, indent=2, ensure_ascii=False) + "\n")
    print(f"✅ 已同步 {TARGET.relative_to(ROOT)}")

    # 根目录配置也写回，保证两份完全一致。
    SOURCE.write_text(json.dumps(unified, indent=2, ensure_ascii=False) + "\n")
    print(f"✅ 已同步 {SOURCE.relative_to(ROOT)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
