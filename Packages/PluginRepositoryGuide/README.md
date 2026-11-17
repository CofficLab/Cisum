# PluginRepositoryGuide

Empty-repository guide: the brand block shown when the current scene's repository has no content.

## Responsibilities

- Provide the guide view (app icon + welcome line) to the player control area via `ControlViewProviding.setGuideSlot`. The block sits where the album cover and track title would be, so the player does not look hollow while the repository is empty.
- Drive the guide's activation from the repository verdict: lit when the repository is confirmed empty, dimmed otherwise. The slot's activation doubles as the "nothing to play" signal for the control area: while it is lit, the progress section is dropped too — there is no track, so there is no progress to show.
- Follow the current scene: the music scene reads the audio repository, the audiobooks scene reads the book repository. The guide takes precedence over a scene's idle hero, so an empty audiobook repository shows the same brand block instead of a "pick a book" placeholder.

Where the repository view is opened is **not** this plugin's business: in the music scene the "more" button carries that hint itself (`PluginAudioControlButtons.MoreButtonGuidanceView`), so the guide does not draw a second, fake "⋯" button. The audiobooks scene has no such bubble, so its guide adds one line of tip text under the title.

The plugin depends only on providers (`ProviderControlView`, `ProviderAudioLibrary`, `ProviderScene`, `ProviderDocsView`); it never depends on another plugin.

## Notes

- "The repository is empty" is a conclusion the data layer owns: the library's `isRepositoryEmpty` is only `true` after a scan has confirmed the repository holds no content. An unscanned repository also counts zero files, which is "not known yet", not "empty".
