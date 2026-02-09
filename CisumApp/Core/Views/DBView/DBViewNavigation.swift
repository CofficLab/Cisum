import SwiftUI

struct DBViewNavigation: View {
    @StateObject var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            List(viewModel.sections) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.items) { item in
                        NavigationLink(value: item) {
                            SettingsItemView(item: item)
                        }
                    }
                }
            }
            .navigationDestination(for: SettingsItem.self) { item in
                if let subItems = item.subItems, !subItems.isEmpty {
                    DBViewNavigation(viewModel: SettingsViewModel(initialSelection: item))
                } else {
                    SettingsDetailView(item: item)
                }
            }
//            .navigationBarTitle("设置")
        }
    }
}

struct SettingsItemView: View {
    let item: SettingsItem
    
    var body: some View {
        Text(item.title)
    }
}

struct SettingsDetailView: View {
    let item: SettingsItem
    
    var body: some View {
        VStack {
            Text(item.title)
                .font(.title)
            Text(item.description ?? "")
        }
    }
}

class SettingsViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var sections: [SettingsSection] = []
    
    init(initialSelection: SettingsItem? = nil) {
        loadSettings()
        
        if let initialSelection {
            navigationPath.append(initialSelection)
        }
    }
    
    private func loadSettings() {
        // 这里模拟加载设置项数据
        let section1 = SettingsSection(title: "账户", items: [
            SettingsItem(title: "电子邮箱", description: "##", subItems: [
                SettingsItem(title: "修改电子邮箱", description: "$$$"),
                SettingsItem(title: "删除账户", description: "###")
            ]),
            SettingsItem(title: "密码", description: "444")
        ])
        
        let section2 = SettingsSection(title: "通知", items: [
            SettingsItem(title: "声音通知", description: "开启或关闭声音通知"),
            SettingsItem(title: "震动通知", description: "开启或关闭震动通知")
        ])
        
        sections = [section1, section2]
    }
}

struct SettingsSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [SettingsItem]
}

struct SettingsItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String?
    var subItems: [SettingsItem]? = nil
    
    init(title: String, description: String?, subItems: [SettingsItem]? = nil) {
        self.title = title
        self.description = description
        self.subItems = subItems
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#Preview {
    DBViewNavigation()
}
