# PluginRegistry

> **Status:** Placeholder directory — no `Package.swift` or source code yet.

This directory is reserved for the plugin registry package, intended to define the plugin registration entry point and registration flow for the Cisum plugin system.

## Functional Logic

- **Intended responsibility:** Define the registry that discovers, registers, and manages all `Plugin`-conforming types in the app, providing lookup and lifecycle management.
- **Current state:** Contains a `.gitignore`, a stale `Package.resolved`, and this README. No Swift source, targets, or products exist.
- **Related package:** `PluginPluginManager` is an active Swift Package that handles plugin management at runtime.

## Testing Logic

- This package has no source code and therefore no unit tests.
- Once source is added, tests can be run with `swift test` from this directory.
