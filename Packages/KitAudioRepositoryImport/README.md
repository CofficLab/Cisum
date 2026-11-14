# KitAudioRepositoryImport

Shared mechanics for importing audio files into the repository.

## Responsibilities

- Filter incoming files: drop folders, unsupported extensions and duplicates.
- Copy files into the repository directory (collision-safe naming, security-scoped access, iCloud readiness).
- Roll back copied files when the audio library is not ready to index them.
- Resolve dropped `NSItemProvider`s into file URLs.

This kit owns **no user-facing text**: every step returns a structured
`AudioRepositoryImportOutcome` and the caller maps it to its own localized
messages. It has no UI and no provider dependencies.
