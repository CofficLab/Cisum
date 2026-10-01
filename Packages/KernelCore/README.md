# KernelCore

> **Status:** Reserved directory — no `Package.swift`, source code, or README yet (contains only a stale `Package.resolved`).

This directory is reserved for the kernel core package, intended to hold the fundamental kernel types and protocols.

## Functional Logic

- **Intended responsibility:** Provide core kernel abstractions (service registry, provider resolution, lifecycle hooks) that higher-level kernel packages build upon.
- **Current state:** Contains only a stale `Package.resolved`. No `Package.swift`, `Sources/`, or `Tests/` exist.

## Testing Logic

- This package has no source code and therefore no unit tests.
- Once source is added, tests can be run with `swift test` from this directory.
