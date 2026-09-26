# CisumKernel

> **Status:** Reserved directory — no `Package.swift` or source code yet (contains only build artifacts).

This directory is reserved for the Cisum kernel package, intended to serve as the central dependency-injection and service-locating core that resolves providers and coordinates plugin lifecycle.

## Functional Logic

- **Intended responsibility:** Host the kernel runtime that resolves `Providing` protocols, manages plugin registration, and wires service dependencies across the app.
- **Current state:** Contains `.build/`, `.swiftpm/`, and `Package.resolved` from prior experimentation, but no `Package.swift`, `Sources/`, or `Tests/`.
- **Related package:** `CisumKernelSupport` provides kernel support utilities and is an active Swift Package.

## Testing Logic

- This package has no source code and therefore no unit tests.
- The `Package.resolved` and `.build` artifacts are stale and can be ignored or cleaned up.
- Once source is added, tests can be run with `swift test` from this directory.
