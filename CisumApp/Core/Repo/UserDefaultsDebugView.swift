import SwiftUI
import MagicKit
import OSLog

/// 用于展示当前应用所有 UserDefaults 键值对的视图
struct UserDefaultsDebugView: View, SuperLog {
    nonisolated static let emoji = "🔍"
    
    @State private var keyValuePairs: [(key: String, value: String)] = []
    @State private var searchText: String
    @State private var showingICloudValues: Bool = false
    
    /// 初始化方法
    /// - Parameter defaultSearchText: 默认的搜索文本，如果提供则在视图加载时自动填充到搜索框
    init(defaultSearchText: String = "") {
        // 使用 _searchText 初始化 @State 变量
        self._searchText = State(initialValue: defaultSearchText)
    }
    
    var filteredPairs: [(key: String, value: String)] {
        if searchText.isEmpty {
            return keyValuePairs
        } else {
            return keyValuePairs.filter { pair in
                pair.key.localizedCaseInsensitiveContains(searchText) ||
                pair.value.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UserDefaults Debug View").font(.headline)

            HStack {
                TextField("Search keys or values", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Toggle("Show iCloud values", isOn: $showingICloudValues)
                    .onChange(of: showingICloudValues) {
                        refreshData()
                    }
            }
            
            Divider()
            
            if filteredPairs.isEmpty {
                Text("No matching key-value pairs found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(filteredPairs, id: \.key) { pair in
                        VStack(alignment: .leading) {
                            Text(pair.key)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(pair.value)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
            }
            
            Divider()
            
            HStack {
                Button("Refresh Data") {
                    refreshData()
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Text("Total: \(filteredPairs.count) items")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refreshData()
        }
    }
    
    /// 刷新显示的数据
    private func refreshData() {
        var pairs: [(key: String, value: String)] = []
        
        if showingICloudValues {
            // 获取 iCloud 键值对
            let store = NSUbiquitousKeyValueStore.default
            store.synchronize() // 确保获取最新数据
            
            let dictionary = store.dictionaryRepresentation
            for key in dictionary.keys.sorted() {
                if let value = dictionary[key] {
                    pairs.append((key: key, value: String(describing: value)))
                }
            }
        } else {
            // 获取 UserDefaults 键值对
            let defaults = UserDefaults.standard
            let dictionary = defaults.dictionaryRepresentation()
            
            for key in dictionary.keys.sorted() {
                if let value = dictionary[key] {
                    pairs.append((key: key, value: String(describing: value)))
                }
            }
        }
        
        self.keyValuePairs = pairs
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#Preview("UserDefaults Debug") {
    UserDefaultsDebugView()
        .frame(width: 600)
        .frame(height: 800)
}

#Preview("With Default Search Value") {
    UserDefaultsDebugView(defaultSearchText: "UI.")
        .frame(width: 600)
        .frame(height: 800)
}

#Preview("Small Screen") {
    RootView {
        UserDefaultsDebugView()
    }
    .frame(width: 500)
    .frame(height: 600)
}

#Preview("Big Screen") {
    RootView {
        UserDefaultsDebugView()
    }
    .frame(width: 800)
    .frame(height: 1200)
}
