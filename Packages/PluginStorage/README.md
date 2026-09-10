# StoragePlugin

Storage management plugin for Cisum, providing file browsing, storage info, migration, and settings.

## Overview

This plugin registers with ID `StoragePlugin` and provides storage management functionality through the Cisum plugin system.

## Architecture

```
StoragePlugin/
├── Package.swift
├── Sources/
│   ├── StoragePlugin.swift
│   ├── Providers/
│   │   └── StorageProvider.swift
│   ├── StoragePluginHost.swift
│   ├── StoragePluginInfo.swift
│   ├── StorageDependencies.swift
│   ├── StorageEvents.swift
│   ├── StorageLocation.swift
│   ├── StorageSettingView.swift
│   ├── FileListView.swift
│   ├── FileItem.swift
│   ├── FileInfoView.swift
│   ├── FileIconView.swift
│   ├── FileSizeView.swift
│   ├── FileStatus.swift
│   ├── FileTitleView.swift
│   ├── FileExpandButton.swift
│   ├── FileStatusColumnView.swift
│   ├── RepositoryInfoView.swift
│   ├── MigrationManager.swift
│   ├── MigrationProgressView.swift
│   └── MigrationError.swift
└── Tests/
```

## Features

- **File Browser**: Browse and manage media files
- **Storage Info**: View storage usage and file details
- **Migration**: Migrate files between storage locations
- **Storage Settings**: Configure storage location preferences

## Maintainers

Work for Joy & Live for Love ➡️ <https://github.com/nookery>
