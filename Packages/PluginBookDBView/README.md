# BookDBViewPlugin

Book database viewer plugin for Cisum, providing a browsable interface for the audiobook library database.

## Overview

This plugin registers with ID `BookDBViewPlugin` and provides audiobook database viewing functionality through the Cisum plugin system.

Database ownership is provided by the separate `PluginBookDBData` plugin. The
view plugin resolves `BookDatabaseProviding` from the Kernel and does not
create the SwiftData container or `BookRepo` itself.

## Architecture

```
BookDBViewPlugin/
├── Package.swift
├── Sources/BookDBViewPlugin/
│   ├── BookDBViewPlugin.swift
│   ├── BookDBViewPluginInfo.swift
│   ├── BookDBView.swift
│   ├── BookDBViewDependencies.swift
│   ├── BookDBEventViews.swift
│   ├── BookDBTips.swift
│   ├── BookGrid.swift
│   ├── BookList.swift
│   ├── BookTile.swift
│   ├── BookPlaybackOrdering.swift
│   ├── BtnChapters.swift
│   └── ChapterTile.swift
└── Tests/
```

## Features

- **Database Browser**: View and browse audiobook library contents
- **Grid & List Views**: Multiple layout options for book display
- **Chapter Navigation**: Browse book chapters with tile views
- **Playback Ordering**: Configure playback order preferences

## Maintainers

Work for Joy & Live for Love ➡️ <https://github.com/nookery>
