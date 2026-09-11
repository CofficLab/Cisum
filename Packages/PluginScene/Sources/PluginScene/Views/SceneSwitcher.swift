import CisumUIComponents
import ProviderScene
import SwiftUI

/// 场景切换器：工具栏入口，列出全部可用场景（如「音乐库」「有声书」），
/// 选择后切换 `currentScene`，从而改变内容区展示的 Tab。
///
/// 由 `ScenePlugin` 通过 `addToolBarButtons()` 贡献到工具栏（迁移自
/// `ProviderToolbar` 的 `DefaultToolbarProviding`）。
struct SceneSwitcher: View {
    @ObservedObject var viewModel: SceneSettingsViewModel

    private var scenes: [AppScene] { viewModel.scenes }
    private var current: AppScene? { viewModel.currentScene }

    var body: some View {
        if scenes.count > 1, let current {
            Button {
                isPresented.toggle()
            } label: {
                Image(systemName: current.iconName)
            }
            .popover(isPresented: $isPresented) {
                PostersView(viewModel: viewModel, dismissAction: { isPresented = false })
                    .frame(minWidth: 350)
            }
        }
    }

    @State private var isPresented = false
}

private struct PostersView: View {
    struct Item: Identifiable {
        let id: String
        let title: String
        let description: String
        let view: AnyView
    }

    @ObservedObject var viewModel: SceneSettingsViewModel
    let dismissAction: @MainActor () -> Void
    @State private var selectedID = ""
    @State private var items: [Item] = []

    var body: some View {
        VStack {
            Picker("", selection: $selectedID) {
                ForEach(items) { item in
                    Text(item.title.isEmpty ? item.id : item.title)
                        .tag(item.id)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if let item = items.first(where: { $0.id == selectedID }) {
                GroupBox {
                    item.view
                }
                .padding()
                Spacer()
            }
        }
        .onAppear { loadItems() }
    }

    /// 场景海报由 PluginScene 自实现：按内置 `AppScene` 枚举逐一渲染，
    /// 不再从其他插件的 `addPosterView()` 贡献中聚合。
    private func loadItems() {
        items = viewModel.scenes.map { scene in
            let title = Self.sceneTitle(scene)
            let description = Self.sceneDescription(scene)
            return Item(
                id: scene.id,
                title: title,
                description: description,
                view: AnyView(
                    ScenePosterView(
                        iconName: scene.iconName,
                        title: title,
                        description: description,
                        enterTitle: String(localized: "Enter Scene", bundle: .module),
                        enterAction: { viewModel.select(scene) },
                        dismissAction: dismissAction
                    )
                )
            )
        }
        selectedID = viewModel.currentScene?.id ?? items.first?.id ?? ""
    }

    private static func sceneTitle(_ scene: AppScene) -> String {
        String(localized: String.LocalizationValue(scene.displayName), bundle: .module)
    }

    private static func sceneDescription(_ scene: AppScene) -> String {
        switch scene {
        case .music:
            String(localized: "Browse and play the music library", bundle: .module)
        case .audiobooks:
            String(localized: "Browse and play the audiobooks", bundle: .module)
        }
    }
}
