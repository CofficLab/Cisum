import Combine
import LumiUI
import ProviderSettingView
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

@MainActor
final class SettingViewManager: SettingViewProviding, ObservableObject {
    @Published private(set) var entries: [SettingEntryItem] = []
    @Published private(set) var selectedEntryID: String?

    func registerEntries(_ entries: [SettingEntryItem]) {
        self.entries = entries.sorted { $0.order < $1.order }
        if selectedEntryID == nil || !self.entries.contains(where: { $0.id == selectedEntryID }) {
            selectedEntryID = self.entries.first?.id
        }
    }

    func selectEntry(id: String?) {
        selectedEntryID = id
    }

    func makeSettingView() -> AnyView {
#if os(macOS)
        AnyView(PluginSettingsShell(provider: self))
#else
        AnyView(MobilePluginSettingsShell(provider: self))
#endif
    }
}

private struct PluginSettingsShell<Provider: SettingViewProviding & ObservableObject>: View {
    @ObservedObject var provider: Provider
    @LumiTheme private var theme

    init(provider: Provider) {
        self.provider = provider
    }

    var body: some View {
        AppSettingsSidebarShell {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 960, minHeight: 520)
        .background(theme.background)
        .appThemedAppearance()
        .onAppear(perform: selectFirstEntryIfNeeded)
#if canImport(AppKit)
        .background {
            ThemeWindowAppearanceBridge()
        }
#endif
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        AppSettingsSidebarContainer(width: 220) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSidebarHeader()

                AppSettingsDivider()

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(provider.entries) { entry in
                            AppSettingsSidebarItem(
                                title: entry.title,
                                systemImage: entry.systemImage,
                                isSelected: provider.selectedEntryID == entry.id
                            ) {
                                provider.selectEntry(id: entry.id)
                            }
                        }
                    }
                    .padding(.leading)
                    .padding(.trailing)
                }

                Spacer()
            }
        }
    }

    private var detail: some View {
        AppSettingsDetailPane {
            Group {
                if let selected = provider.entries.first(where: { $0.id == provider.selectedEntryID }) {
                    selected.makeDetailView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AppEmptyState(icon: "gearshape", title: LumiPluginLocalization.string("Select a tab", bundle: .module))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func selectFirstEntryIfNeeded() {
        guard provider.selectedEntryID == nil,
              let firstEntry = provider.entries.first else { return }
        provider.selectEntry(id: firstEntry.id)
    }
}

private struct SettingsSidebarHeader: View {
    private let appInfo = AppBundleInfo()

    var body: some View {
        AppSettingsSidebarHeader(
            name: appInfo.name,
            version: appInfo.version,
            build: appInfo.build,
            topSpacing: 22,
            bottomSpacing: 8
        ) {
            HStack {
                Spacer()
                CurrentAppIconView()
                    .frame(width: 64, height: 64)
                Spacer()
            }
        }
    }
}

#if os(macOS)
private struct CurrentAppIconView: View {
    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .scaledToFit()
    }
}
#elseif os(iOS) || os(visionOS)
private struct CurrentAppIconView: View {
    var body: some View {
        if let image = CurrentAppIcon.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }
}

/// 从主 App 的图标配置读取当前图标，而不是把 AppIcon.appiconset 当普通图片资源读取。
@MainActor
private enum CurrentAppIcon {
    static var image: UIImage? {
        let info = Bundle.main.infoDictionary ?? [:]
        let iconsKey = UIDevice.current.userInterfaceIdiom == .pad
            ? "CFBundleIcons~ipad"
            : "CFBundleIcons"
        let icons = (info[iconsKey] as? [String: Any]) ?? (info["CFBundleIcons"] as? [String: Any])

        if let alternateName = UIApplication.shared.alternateIconName,
           let alternateIcons = icons?["CFBundleAlternateIcons"] as? [String: [String: Any]],
           let alternateIcon = alternateIcons[alternateName],
           let image = loadImage(from: alternateIcon) {
            return image
        }

        guard let primaryIcon = icons?["CFBundlePrimaryIcon"] as? [String: Any] else {
            return nil
        }
        return loadImage(from: primaryIcon)
    }

    private static func loadImage(from icon: [String: Any]) -> UIImage? {
        guard let iconFiles = icon["CFBundleIconFiles"] as? [String] else {
            return nil
        }
        return iconFiles.lazy.compactMap { UIImage(named: $0) }.first
    }
}
#endif

#if os(iOS) || os(visionOS)
/// iOS / visionOS 设置外壳：紧凑宽度使用分层导航，Regular 宽度使用双栏导航。
///
/// 设置入口仍来自 `SettingViewProviding`，这里只负责 iOS 的呈现方式；
/// 具体设置内容继续由各自插件通过 `SettingEntryItem` 提供。
///
/// 根页遵循 iOS Settings 范式：分组 inset 列表 + 导航栏搜索 + 纯文字行（不画前置图标）。
private struct MobilePluginSettingsShell<Provider: SettingViewProviding & ObservableObject>: View {
    @ObservedObject var provider: Provider
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var path: [SettingEntryRoute] = []
    @State private var searchText = ""

    init(provider: Provider) {
        self.provider = provider
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularSettings
            } else {
                compactSettings
            }
        }
        .onAppear(perform: selectFirstEntryIfNeeded)
    }

    private var compactSettings: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    appIdentityHeader
                }

                ForEach(cards) { card in
                    if let title = card.title {
                        Section {
                            entryRows(card.entries)
                        } header: {
                            Text(title)
                        }
                    } else {
                        Section {
                            entryRows(card.entries)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(LumiPluginLocalization.string("Settings", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: LumiPluginLocalization.string("Search", bundle: .module))
            .navigationDestination(for: SettingEntryRoute.self) { route in
                detailView(for: route.entryID)
            }
            .onChange(of: path) { _, newPath in
                provider.selectEntry(id: newPath.last?.entryID)
            }
            .toolbar { doneButton }
        }
    }

    private var regularSettings: some View {
        NavigationSplitView {
            List(selection: selection) {
                Section {
                    appIdentityHeader
                }

                ForEach(cards) { card in
                    if let title = card.title {
                        Section {
                            entryRows(card.entries)
                        } header: {
                            Text(title)
                        }
                    } else {
                        Section {
                            entryRows(card.entries)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(LumiPluginLocalization.string("Settings", bundle: .module))
        } detail: {
            if let selectedEntryID = provider.selectedEntryID {
                detailView(for: selectedEntryID)
            } else {
                AppEmptyState(icon: "gearshape", title: LumiPluginLocalization.string("Select a tab", bundle: .module))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar { doneButton }
    }

    @ViewBuilder
    private func entryRows(_ entries: [SettingEntryItem]) -> some View {
        ForEach(entries) { entry in
            NavigationLink(value: SettingEntryRoute(entryID: entry.id)) {
                Text(entry.title)
            }
            .accessibilityIdentifier("kuzee.settings.entry.\(entry.id)")
        }
    }

    /// 过滤后的入口分组（已把连续的无标题分组合并成一张卡片）。
    private var cards: [SettingEntryGrouping.Card] {
        SettingEntryGrouping.cards(from: provider.entries, keyword: searchText)
    }

    private var appIdentityHeader: some View {
        HStack(spacing: 12) {
            CurrentAppIconView()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(AppBundleInfo().name)
                    .font(.headline)

                let appInfo = AppBundleInfo()
                Text([appInfo.version.map { "v\($0)" }, appInfo.build.map { "Build \($0)" }]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var selection: Binding<String?> {
        Binding(
            get: { provider.selectedEntryID },
            set: { provider.selectEntry(id: $0) }
        )
    }

    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(LumiPluginLocalization.string("Done", bundle: .module)) {
                dismiss()
            }
            .accessibilityIdentifier("kuzee.settings.done")
        }
    }

    @ViewBuilder
    private func detailView(for entryID: String) -> some View {
        if let entry = provider.entries.first(where: { $0.id == entryID }) {
            entry.makeDetailView()
                .navigationTitle(entry.title)
                .navigationBarTitleDisplayMode(.inline)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            AppEmptyState(icon: "gearshape", title: LumiPluginLocalization.string("Setting unavailable", bundle: .module))
        }
    }

    private func selectFirstEntryIfNeeded() {
        guard provider.selectedEntryID == nil,
              let firstEntry = provider.entries.first else { return }
        provider.selectEntry(id: firstEntry.id)
    }
}
#endif
