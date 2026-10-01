# ProviderStore

Defines the in-app purchase / subscription layer: `StoreService` (StoreKit 2 bootstrap, product fetching, purchases, entitlement calibration), the value DTOs that mirror StoreKit types, `StoreState` (cached entitlement persistence), `StoreConfig` (product-ID → tier mapping), and notification events.

## Functional Logic

- **Core responsibility**: fetch App Store products, classify them into cars/consumables/subscriptions/non-renewables, perform verified purchases, and derive the current highest subscription tier from `Transaction.currentEntitlements`.
- **Key types**:
  - **DTOs** (`DTO/`):
    - `ProductDTO` (`Identifiable, Hashable, Sendable`): `id`, `displayName`, `displayPrice`, `price: Decimal`, `kind` (`.consumable/.nonConsumable/.autoRenewable/.nonRenewable/.unknown`), `description`, `subscription: SubscriptionInfoDTO?`. `Product.toDTO(_:)` maps StoreKit products.
    - `SubscriptionInfoDTO`: period, introductory/promotional offer info, `groupDisplayName`, `groupID`. `IntroductoryOfferDTO`, `StoreSubscriptionPeriodDTO`, `StoreSubscriptionStatusDTO` (verification flags + renewal info).
    - `SubscriptionGroupDTO`: `name`, `id`, `subscriptions: [ProductDTO]`.
    - `ProductGroupsDTO`: buckets `cars` (non-consumables), `subscriptionGroups`, `nonRenewables`, `fuel` (consumables); `createSubscriptionGroups(from:)` aggregates subscriptions by group ID and sorts by price; `subscriptions` flattens all groups.
  - **Models** (`Models/`):
    - `PurchaseInfo` (`Codable, Equatable, Sendable`): `tier: SubscriptionTier`, `expiresAt: Date?`; computed `isProOrHigher`, `effectiveTier`, `isExpired` (60s grace), `expiresAtString`.
    - `SubscriptionTier` (`none=0`, `pro=1`, `ultimate=2`, `Comparable`).
    - `StoreConfig`: private mapping of product IDs to tiers; `allProductIds`, `tier(for:)`.
    - `StoreState`: `ObservableObject` that persists `PurchaseInfo` to `UserDefaults` (`store.purchase`, `store.lastCheckedAt`), calibrates from `Transaction.currentEntitlements`, and merges the highest tier / latest expiry.
    - `StorePluginInfo`: title/description/icon metadata.
    - `StoreEvents`: `.storeTransactionUpdated` / `.Restored` notification names and SwiftUI `onRestored` / `onStoreTransactionUpdated` view helpers.
  - **Service** (`Services/StoreService.swift`):
    - `bootstrap()` / `startTransactionListener()` — idempotent transaction-update loop.
    - `fetchAllProducts()`, `fetchAllSubscriptionGroups()`, `fetchPurchasedLists(cars:subscriptions:nonRenewables:)`.
    - `purchase(_ product: ProductDTO)` — verified purchase, updates state, finishes transaction (no-op on visionOS).
    - `getPurchaseInfo()`, `cachedPurchaseInfo()`, `tierCached()`, `expiresAtCached()`.
    - `inspectSubscriptionStatus(_:verbose:)` — returns subscriptions, statuses, and the highest active product/status; `highestActiveSubscriptionStatusIndex` skips expired/revoked/unknown.
    - `computeExpirationDate(from:)` handles subscribed/expired/revoked/inGracePeriod/inBillingRetry.
    - `checkVerified(_:)` throws `StoreError.failedVerification` on unverified results.
- **Dependencies**: `MagicKit`, `CisumUIComponents` (`SuperLog`, `fullDateTime` helper), `StoreKit`.

## Testing Logic

- **Test file**: `Tests/ProviderStoreTests.swift`.
- **Key scenarios tested**:
  - `PurchaseInfo` entitlement/expiry flags (active vs. expired, effective tier, `expiresAtString` suffixes).
  - `SubscriptionTier` ordering, `isFreeVersion`/`isProOrHigher`/`isUltimateOrHigher`, display names, Codable round-trip.
  - `StoreConfig.allProductIds` set and `tier(for:)` lookups (including unknown products → `.none`).
  - `ProductGroupsDTO` flattening, group lookup, classification buckets, and `createSubscriptionGroups` grouping/sorting.
  - `StoreSubscriptionPeriodDTO` Codable and `Product.SubscriptionPeriod.Unit.description` mapping.
  - `highestActiveSubscriptionStatusIndex` skipping expired/revoked/unknown entries.
  - `StoreState` persist/clear round-trip through `UserDefaults`; expired non-renewables grant no tier; calibration keeps the highest tier and latest valid expiration.
  - `checkVerified` throws on unverified; `computeExpirationDate(nil)` → `.distantPast`; listener start guard.
  - `StorePluginInfo`, `StoreError` localized descriptions, notification-name raw values; `.storeTransactionUpdated` posts the product ID on the notification object.
- **Running tests**:
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/ProviderStore
  swift test
  ```
- **Note**: tests cover the pure DTO/config/state logic; live StoreKit requests are not exercised in unit tests.
