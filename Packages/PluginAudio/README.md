# AudioPlugin

Root audio UI plugin for Cisum. The catalog implementation lives in `PluginAudioDBData`; this package owns the root view and storage availability gate.

## Overview

This plugin registers with ID `AudioPlugin` and provides the core audio library functionality through the Cisum plugin system. It serves as the foundation for other audio-related plugins.

## Architecture

```
PluginAudio             → root view and storage readiness UI
PluginAudioDBData       → SwiftData catalog, repository, filesystem sync
ProviderAudioLibrary    → catalog contracts and typed events
ProviderAudioNavigation → track navigation contract
```

## Features

- **Root View**: Main audio library interface
- **Storage Gate**: Shows setup/error state until Storage is available
- **Contract Consumer**: Resolves catalog capabilities from Kernel without static hosts

## Maintainers

Work for Joy & Live for Love ➡️ <https://github.com/nookery>
