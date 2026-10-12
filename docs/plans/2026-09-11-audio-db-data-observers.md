# PluginAudioDBData Observer Layout Plan

**Goal:** Align `PluginAudioDBData` with the repository convention that lifecycle subscriptions live under `Sources/Observers`.

**Design:** `AudioStorageObserver` owns the `StorageProviding` subscription handle and cancellation lifecycle. The plugin entry uses it to restart filesystem synchronization after a storage change; `AudioLibraryProvider` uses the same observer to invalidate its cached repository. Filesystem reconciliation remains under `Sources/Synchronization` because it performs synchronization work rather than merely forwarding events.

## Implementation status

Completed on 2026-09-11:

- Added `Sources/Observers/AudioStorageObserver.swift`.
- Moved both data-layer storage subscriptions behind the observer object.
- Added the observer directory to the documented `PluginAudioDBData` tree.
- Kept synchronization behavior and teardown semantics unchanged.
