# PluginAudioDBData Directory Layout Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement the plan task-by-task.

**Goal:** Organize `PluginAudioDBData` by responsibility so its implementation boundaries are visible from the directory tree without changing runtime behavior.

**Architecture:** Keep plugin lifecycle assembly, concrete Provider adapters, SwiftData models, persistence services, filesystem reconciliation, event bridges, errors, and filesystem extensions in separate directories. Keep `ProviderAudioLibrary` contract-only; this change only moves concrete data-plugin files.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftData.

---

### Task 1: Move source files into responsibility-based directories

Move the plugin entry to `Sources/Plugin`, the navigation and library adapters to `Sources/Providers`, persistence files to `Sources/Persistence`, the file monitor to `Sources/Synchronization`, the notification bridge to `Sources/Events`, errors to `Sources/Errors`, and URL helpers to `Sources/Extensions`. Remove the empty legacy `Implementation` directory.

### Task 2: Document the layout

Update `Packages/PluginAudioDBData/README.md` with the tree and the ownership rule: all concrete audio data behavior remains inside this plugin, while public cross-plugin contracts remain in Provider packages.

### Task 3: Verify the structure

Run `swift test --package-path Packages/PluginAudioDBData`, `swift build --package-path Packages/FactoryCisum`, `./Scripts/check-plugin-boundaries.sh`, and `git diff --check`. Confirm no source file remains under `Sources/Implementation` and no production import/reference changes are introduced by the moves.

## Implementation status

Completed on 2026-09-11:

- Removed the generic `Sources/Implementation` bucket.
- Grouped plugin assembly, concrete Providers, models, persistence, synchronization, events, errors, and extensions by responsibility.
- Documented the final tree in `Packages/PluginAudioDBData/README.md`.
