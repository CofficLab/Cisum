import CisumUIComponents
import SwiftUI

/// 内容 Tab 容器视图。
///
/// 展示已注入的 Tab 视图；尚未注入任何 Tab 时展示占位说明。
struct ContentAreaView: View {
    @ObservedObject var provider: DefaultContentViewProvider
    @LumiTheme private var appTheme
    @State private var selectedTab = 0
    let isDemoMode: Bool

    private var tabs: [ContentTabItem] { provider.tabs }

    var body: some View {
        Group {
            if tabs.count == 1, let tab = tabs.first {
                tab.content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                #if os(macOS)
                    macTabView
                #else
                    if isDemoMode {
                        customTabView
                    } else {
                        regularTabView
                    }
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appTheme.background)
        .onChange(of: tabs.map(\.id)) { _, _ in
            selectedTab = 0
        }
        .onChange(of: tabs.count) { _, newCount in
            if selectedTab >= newCount { selectedTab = max(0, newCount - 1) }
        }
    }

    @ViewBuilder
    private var regularTabView: some View {
        if tabs.isEmpty {
            EmptyTabView()
        } else {
            #if os(macOS)
                if #available(macOS 15.0, *) {
                    tabView
                        .tabViewStyle(GroupedTabViewStyle())
                        .padding(.top, 2)
                } else {
                    tabView
                        .padding(.top, 2)
                }
            #else
                tabView
            #endif
        }
    }

    private var tabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                tab.content
                    .tag(index)
                    .tabItem { Label(tab.title, systemImage: "music.note") }
            }
        }
    }

    private var customTabView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button {
                        withAnimation { selectedTab = index }
                    } label: {
                        Text(tab.title)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedTab == index ? appTheme.primary : appTheme.textSecondary)
                            .background(
                                selectedTab == index ? appTheme.primary.opacity(0.1) : .clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 0)
            .background(appTheme.textSecondary.opacity(0.1))

            if let tab = tabs[safe: selectedTab] {
                tab.content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                EmptyTabView()
            }
        }
    }

    /// macOS kept the 3.10 player-style tab strip instead of the system
    /// bottom-tab presentation. ViewThatFits keeps the centered treatment at
    /// normal widths while allowing the tabs to scroll in a narrow window.
    private var macTabView: some View {
        VStack(spacing: 0) {
            macTabBar
                .padding(6)
            Divider()

            if let tab = tabs[safe: selectedTab] {
                tab.content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                EmptyTabView()
            }
        }
    }

    private var macTabBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                macTabButtons
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    macTabButtons
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var macTabButtons: some View {
        ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
            Button {
                withAnimation { selectedTab = index }
            } label: {
                Label(tab.title, systemImage: "music.note")
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(selectedTab == index ? appTheme.textPrimary : appTheme.textSecondary)
                    .background(
                        selectedTab == index ? appTheme.primary : appTheme.elevatedSurface,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
            }
            .buttonStyle(.plain)
            .help(tab.title)
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
