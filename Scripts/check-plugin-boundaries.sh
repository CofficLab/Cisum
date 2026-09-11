#!/bin/zsh

set -euo pipefail

workspace_root="${0:A:h}/.."
cd "$workspace_root"

scope=(
  Packages/PluginBook*
  Packages/PluginAudio*
  Packages/PluginStore
)

if rg -n '^import Plugin[A-Z]' "${scope[@]}" \
  --glob '*.swift' \
  --glob '!**/Tests/**' \
  --glob '!**/.build/**'; then
  print -u2 'Plugin boundary violation: a feature source imports another Plugin module.'
  exit 1
fi

if rg -n '\.product\(name: "Plugin(Book|Audio|Store)' "${scope[@]}" \
  --glob 'Package.swift'; then
  print -u2 'Plugin boundary violation: a target depends on another Plugin product.'
  exit 1
fi

if rg -n '\.package\((name: "[^"]+", )?path: "\.\./Plugin(Book|Audio|Store)' "${scope[@]}" \
  --glob 'Package.swift'; then
  print -u2 'Plugin boundary violation: a feature package depends on another Plugin package.'
  exit 1
fi

provider_scope=(
  Packages/ProviderAudioLibrary/Sources
  Packages/ProviderAudioLike/Sources
)

if rg -n '^import (SwiftData|SwiftUI|OSLog|ProviderStorage|CisumUIComponents|MagicKit)' "${provider_scope[@]}" \
  --glob '*.swift'; then
  print -u2 'Provider boundary violation: an Audio Provider imports implementation or UI dependencies.'
  exit 1
fi

if rg -n '^[^/]*(FileManager|UserDefaults|NotificationCenter|AudioDB|AudioRepo|AudioLikeRepo)' "${provider_scope[@]}" \
  --glob '*.swift' \
  --glob '!**/README.md'; then
  print -u2 'Provider boundary violation: an Audio Provider contains concrete storage, repository, or global-event logic.'
  exit 1
fi

consumer_scope=(
  Packages/PluginAudio
  Packages/PluginAudioCopy
  Packages/PluginAudioDBView
  Packages/PluginAudioPlayMode
  Packages/PluginAudioProgress
  Packages/PluginAudioSettings
  Packages/PluginAudioWidgetControl
)

if rg -n 'AudioPluginHost|getAudioRepoAsync|getAudioRepo\(|(^|[^A-Za-z])AudioRepo\(' "${consumer_scope[@]}" \
  --glob '*.swift' \
  --glob '!**/Tests/**' \
  --glob '!**/.build/**'; then
  print -u2 'Provider boundary violation: a consumer uses an Audio concrete host or repository.'
  exit 1
fi

print 'Plugin boundary check passed.'
