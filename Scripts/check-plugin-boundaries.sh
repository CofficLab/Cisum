#!/bin/zsh

set -euo pipefail

workspace_root="${0:A:h}/.."
cd "$workspace_root"

plugin_source_scope=(Packages/Plugin*/Sources)
plugin_package_scope=(Packages/Plugin*/Package.swift)

if rg -n '^import Plugin[A-Z]' "${plugin_source_scope[@]}" \
  --glob '*.swift' \
  --glob '!**/Tests/**' \
  --glob '!**/.build/**'; then
  print -u2 'Plugin boundary violation: a feature source imports another Plugin module.'
  exit 1
fi

if rg -n '\.product\(name: "Plugin[A-Z]' "${plugin_package_scope[@]}" \
  --glob 'Package.swift'; then
  print -u2 'Plugin boundary violation: a target depends on another Plugin product.'
  exit 1
fi

if rg -n '\.package\((name: "[^"]+", )?path: "\.\./Plugin[A-Z]' "${plugin_package_scope[@]}" \
  --glob 'Package.swift'; then
  print -u2 'Plugin boundary violation: a feature package depends on another Plugin package.'
  exit 1
fi

business_environment_scope=(
  Packages/Plugin*/Sources
  Packages/Provider*/Sources
  Packages/FactoryCisum/Sources
  Packages/CisumUIComponents/Sources
)

if rg -n '@EnvironmentObject|\.environmentObject\(|EnvironmentKey|EnvironmentValues|@Environment\(\.(demoMode|appIsImporting|showAudioDBViewAction|pluginThemes|currentPluginThemeId|selectPluginThemeAction|resetSettingsAction|sceneProviding|posterDismissAction|toastProviding|audioDBDependencies|bookDBDependencies|bookDBImportAction|pluginStorageDependencies)\)' \
  "${business_environment_scope[@]}" \
  --glob '*.swift' \
  --glob '!**/Tests/**' \
  --glob '!**/.build/**'; then
  print -u2 'Environment boundary violation: business dependencies must be explicit provider/plugin inputs.'
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

playback_ui_scope=(
  Packages/FactoryCisum/Sources/FactoryCisum/Views
  Packages/ProviderControlView/Sources
  Packages/ProviderPlayback/Sources
)

if rg -n '@EnvironmentObject[^\n]*MagicPlayMan|as\?\s*MagicPlayMan|^import MagicPlayMan' "${playback_ui_scope[@]}" \
  --glob '*.swift'; then
  print -u2 'Playback boundary violation: UI/provider layers depend on MagicPlayMan concrete state or environment objects.'
  exit 1
fi

print 'Plugin boundary check passed.'
