# PluginRepositoryGuide

Empty-repository guide: the brand block shown when the music repository has no content.

## Responsibilities

- Provide the guide view (app icon + welcome line) to the player control area via `ControlViewProviding.setGuideSlot`. The block sits where the album cover and track title would be, so the player does not look hollow while the repository is empty.
- Drive the guide's activation from the repository verdict: lit when the repository is confirmed empty, dimmed otherwise. The slot's activation doubles as the "nothing to play" signal for the control area: while it is lit, the progress section is dropped too — there is no track, so there is no progress to show.
- Keep the guide scoped to the music scene.

Where the repository view is opened is **not** this plugin's business: the "more" button carries that hint itself (`PluginAudioControlButtons.MoreButtonGuidanceView`), so the guide does not draw a second, fake "⋯" button.

The plugin depends only on providers (`ProviderControlView`, `ProviderAudioLibrary`, `ProviderScene`, `ProviderDocsView`); it never depends on another plugin.

## Notes

- "The repository is empty" is a conclusion the data layer owns: `AudioLibraryProviding.isRepositoryEmpty` is only `true` after a scan has confirmed the repository holds no audio. An unscanned repository also counts zero files, which is "not known yet", not "empty".
