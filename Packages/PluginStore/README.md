# PluginStore

The in-app purchase / subscription settings plugin. It contributes a "Store" settings entry showing the current subscription tier, a purchase sheet with a free-vs-Pro comparison and product list, and a restore-purchases sheet.

## Functional Logic

- **Core responsibility:** Surface subscription status, drive StoreKit product loading/purchase/restore, and present the purchase and restore sheets. It relies on `ProviderStore` for the actual StoreKit service layer (`StoreService`, `StoreConfig`, DTOs).
- **Key types:**
  - `StorePlugin` — `@MainActor final class` conforming to `AsyncSuperPlugin, SuperLog`. `id = "StorePlugin"`, `order = 80`, category `.system`, policy `.alwaysOn`.
  - `StoreObserver` — observes `.storeTransactionUpdated` and `.Restored` notifications and triggers `StoreViewModel.updatePurchaseInfo()`.
  - `StoreViewModel` — `ObservableObject` publishing sheet visibility (`showBuySheet`, `showRestoreSheet`), `purchaseInfo`, `tierDisplayName`, and `statusDescription`; uses a generation counter to ignore stale async purchase-info loads.
  - `StoreSetting` — public settings view showing current version, subscription status/expiration, and buttons to open the buy/restore sheets.
  - `PurchaseView` — purchase sheet embedding `VersionComparisonView` and `ProductsSubscription`, with privacy/EULA links.
  - `RestoreView` — restore sheet calling `AppStore.sync()` with idle/restoring/success/failed states.
  - `ProductsSubscription` (in `Subscriptions.swift`) — loads subscription groups via `StoreService.fetchAllProducts()`, shows loading/error/empty/content states with a generation guard, and renders `ProductCell`s.
  - `VersionComparisonView` — free vs Pro feature cards.
  - Supporting views: `ProductCell`, `SheetContainer` (with a localized close button), `DebugView`.
  - `ProviderStoreExports` — re-exports `ProviderStore` and `ProviderAudioLibrary` for consumers.
  - Views: `StorePluginAboutView`, `StorePluginManualView`.
- **Plugin registration:** Registers as `StorePlugin`. `onRegister` contributes About/Manual docs. `onBootAsync` contributes the "store" settings navigation item and assembles the view model + observer. `onShutdownAsync` removes the contribution and cancels observer tokens.
- **Workflow/data flow:**
  1. On appear/transaction/restore events, `StoreViewModel.updatePurchaseInfo()` calls `StoreService.getPurchaseInfo()` and updates tier/status text (Pro active/expired/free).
  2. Tapping buy opens `PurchaseView`, which loads products via `StoreService` and triggers purchases; transactions post `.storeTransactionUpdated`.
  3. Tapping restore runs `AppStore.sync()` and posts `.Restored` on success.
- **Dependencies:** `MagicKit`, `CisumUIComponents`, `ProviderStore`, `ProviderAudioLibrary`, `CisumKernelSupport`, `ProviderDocsView`. Platforms: macOS 14+, iOS 17+. Resources: `Resources/Localizable.xcstrings`, `Resources/Products.storekit`.

## Testing Logic

- **Test files:**
  - `Tests/StorePluginTests.swift`.
- **Key scenarios tested:**
  - Metadata: `StorePluginInfo.titleKey = "Store"`, `iconName = "cart"`, `SubscriptionTier.none.isFreeVersion`.
  - Pro product-ID aliases map to `.pro` and are included in `StoreConfig.allProductIds`.
  - Highest active subscription index selects an active subscribed subscription and ignores expired ones.
  - Product-list state machine: loading/error/empty/content transitions; only the latest load result is applied; singular vs plural count text.
  - Purchase-info generation guard; readable labels for purchase/restore/close buttons; `StoreError` user-facing descriptions; transaction listener starts only once.
  - `StoreService.postTransactionUpdated` posts `.storeTransactionUpdated` with the product ID.
  - Plugin assembles/reuses the view model; `StoreObserver.cancel()` is idempotent; view model starts in the free presentation state.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginStore
  swift test
  ```
- Tests focus on the pure StoreKit-adjacent policies (tier mapping, state machines, generation guards, labels); real App Store transactions are not executed.
