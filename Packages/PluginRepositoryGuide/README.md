# PluginRepositoryGuide

First-run guide shown when the repository is empty.

## Responsibilities

- Provide the guide view (brand area + drop target) to the player control area via `ControlViewProviding.setGuideSlot`.
- Drive the guide's activation from repository events: lit when the repository is confirmed empty, dimmed otherwise.
- Keep the guide scoped to the music scene, and let the import flow share `KitAudioRepositoryImport` with the repository view.

The plugin depends only on providers (`ProviderControlView`, `ProviderAudioLibrary`,
`ProviderScene`, `ProviderToast`) and `KitAudioRepositoryImport`; it never depends on
another plugin.
