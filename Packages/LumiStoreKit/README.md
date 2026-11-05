# LumiStoreKit

StoreKit 2 lifecycle utilities for Coffic Lab apps.

`LumiStoreKit` is the **business-agnostic tool layer** for in-app purchases. It follows the same
layering discipline as the rest of the Coffic Lab packages:

| Layer | Package | Knows about |
| --- | --- | --- |
| Contract | `ProviderStore` (in [LumiProviders](https://github.com/CofficLab/LumiProviders)) | Subscription tiers, entitlement snapshots, capability protocols |
| Tool | `KitStoreKit` (this package) | StoreKit mechanics only |
| Feature | Each app's `PluginStore` | Product catalog, purchase UI, settings pages |

## What this package does not know

- **Subscription tiers.** Pro / Ultimate are product semantics that differ per app, so they belong
  to the `ProviderStore` contract, not here.
- **Any app's product IDs.** The product ID list is injected per app through
  `StoreKitConfiguration`.

That keeps the dependency direction `Provider → Kit`. This package has no Provider dependency.

## Features

- **Transaction listener** — `Transaction.updates` loop with idempotent start and explicit stop.
- **Entitlement calibration** — reads `Transaction.currentEntitlements`, skipping unverified
  transactions.
- **Subscription aggregation** — `StoreKitSubscriptionAggregator` derives the currently active
  subscription holding (which product IDs are active, and the latest expiration) from transaction
  summaries. It is a pure function, so it is fully unit tested.
- **Product fetching** — cached request of the configured product ID list.
- **Purchase and restore** — verified purchase flow and `AppStore.sync()`-based restore.
- **Transaction verification** — unverified results are always rejected.
- **Entitlement persistence** — pluggable storage (`UserDefaults` by default).

## Usage

An app supplies its product list and receives entitlement changes:

```swift
import KitStoreKit

let configuration = StoreKitConfiguration(
    productIDs: [
        "com.example.pro.monthly",
        "com.example.pro.yearly",
    ],
    entitlementStorageKey: "store.purchase",
    lastCheckedAtStorageKey: "store.lastCheckedAt"
)

let service = StoreKitService(configuration: configuration) { holding in
    // Called on the main thread whenever entitlements change.
    print(holding.activeSubscriptionProductIDs, holding.latestExpiration as Any)
}

await service.bootstrap()
```

The app then maps active product IDs onto its own tiers using the `ProviderStore` contract:

```swift
import ProviderStore

struct MyStoreCatalog: StoreProductCatalog {
    let productTiers: [String: StoreTier] = [
        "com.example.pro.monthly": .pro,
        "com.example.pro.yearly": .pro,
    ]
}

let tier = holding.activeSubscriptionProductIDs
    .map { catalog.tier(for: $0) }
    .max() ?? .none
```

## Requirements

- Swift tools 6.0+
- macOS 14+
- iOS 17

## Tests

```sh
swift test
```
