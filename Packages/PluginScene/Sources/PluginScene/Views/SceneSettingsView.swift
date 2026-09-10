import CisumUIComponents
import SwiftUI

/// 场景设置页：展示当前场景，并通过 `SceneSettingsViewModel` 切换场景。
///
/// 只观察入口注入的 ViewModel，不直接读取 Provider，也不在 `.onAppear` /
/// `.onDisappear` 中创建/销毁监听。
struct SceneSettingsView: View {
    @ObservedObject var model: SceneSettingsViewModel

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                AppSettingSection(
                    title: String(localized: "Current Scene", bundle: .module)
                ) {
                    AppSettingRow(
                        title: model.currentScene?.displayName ?? String(localized: "No scene selected", bundle: .module),
                        description: String(localized: "The scene currently shown in the main window", bundle: .module),
                        icon: model.currentSceneIconName
                    ) {
                        if model.currentScene != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                AppSettingSection(
                    title: String(localized: "Available Scenes", bundle: .module)
                ) {
                    if model.scenes.isEmpty {
                        AppSettingRow(
                            title: String(localized: "No scenes available", bundle: .module),
                            description: String(localized: "No built-in scenes are available", bundle: .module),
                            icon: "rectangle.3.group"
                        ) {
                            EmptyView()
                        }
                    } else {
                        ForEach(model.scenes, id: \.id) { scene in
                            AppSettingRow(
                                title: scene.displayName,
                                description: String(localized: "Switch to this scene", bundle: .module),
                                icon: scene.iconName,
                                titleSuffix: {
                                    if model.currentScene == scene {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                },
                                action: { model.select(scene) }
                            ) {
                                if model.currentScene == scene {
                                    Text(String(localized: "Current", bundle: .module))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
