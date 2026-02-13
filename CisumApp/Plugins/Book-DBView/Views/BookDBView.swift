import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BookDBView: View, SuperLog, SuperThread {
    nonisolated static let emoji = "🐘"
    nonisolated static let verbose = false
    
    @EnvironmentObject var app: AppProvider
    
    @State var treeView = false
    
    /// 是否正在拖拽文件
    var dropping: Bool { app.isDropping }
    
    /// 是否使用列表视图，默认为网格视图
    private var useListView = false

    var body: some View {
        if Self.verbose {
            os_log("\(self.t)📺 开始渲染")
        }
        return VStack(spacing: 0) {
            if useListView {
                BookList()
            } else {
                BookGrid()
            }
        }
        .fileImporter(
            isPresented: $app.isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $app.isDropping, perform: handleDrop)
        .onAppear(perform: handleOnAppear)
    }
}

// MARK: - Action

extension BookDBView {
    /// 复制文件到仓库
    ///
    /// 将选中或拖拽的文件复制到书籍仓库中。
    ///
    /// - Parameter files: 要复制的文件 URL 数组
    func copy(_ files: [URL]) {
        if Self.verbose {
            os_log("\(self.t)📂 准备复制 \(files.count) 个文件")
        }
        
        // TODO: 实现文件复制逻辑
    }
}

// MARK: - Event Handler

extension BookDBView {
    /// 处理视图出现事件
    ///
    /// 当视图首次出现在屏幕上时触发，用于执行初始化操作。
    func handleOnAppear() {
        if Self.verbose {
            os_log("\(self.t)👀 视图已出现")
        }
        
        // TODO: 可以在这里执行初始化逻辑，例如：
        // - 检查数据完整性
        // - 加载缓存数据
        // - 更新统计信息
    }
    
    /// 处理文件导入结果
    ///
    /// 当用户通过文件选择器导入文件后触发。
    ///
    /// - Parameter result: 文件导入的结果，包含选中的文件 URL 或错误信息
    func handleFileImport(_ result: Result<[URL], Error>) {
        if Self.verbose {
            os_log("\(self.t)📥 处理文件导入")
        }
        
        switch result {
        case let .success(urls):
            if Self.verbose {
                os_log("\(self.t)✅ 成功导入 \(urls.count) 个文件")
            }
            copy(urls)
            
        case let .failure(error):
            os_log(.error, "\(self.t)❌ 导入文件失败: \(error.localizedDescription)")
        }
    }
    
    
    /// 处理文件拖拽事件
    ///
    /// 当用户拖拽文件到视图上时触发，异步加载所有拖拽的文件 URL 并复制。
    ///
    /// ## 处理流程
    /// 1. 创建 DispatchGroup 协调所有异步加载
    /// 2. 遍历所有 provider，异步加载文件 URL
    /// 3. 收集所有成功加载的文件
    /// 4. 在主线程调用 copy 方法批量复制
    ///
    /// - Parameter providers: 拖拽提供者数组，每个包含一个文件引用
    /// - Returns: 始终返回 `true` 表示接受拖拽
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if Self.verbose {
            os_log("\(self.t)🎯 处理文件拖拽，提供者数量: \(providers.count)")
        }
        
        let dispatchGroup = DispatchGroup()
        var droppedFiles: [URL] = []
        
        for provider in providers {
            dispatchGroup.enter()
            
            // 异步加载文件对象
            _ = provider.loadObject(ofClass: URL.self) { object, error in
                defer { dispatchGroup.leave() }
                
                if let url = object {
                    if Self.verbose {
                        os_log("\(self.t)📎 添加 \(url.lastPathComponent) 到复制队列")
                    }
                    droppedFiles.append(url)
                } else if let error = error {
                    os_log(.error, "\(self.t)⚠️ 加载文件失败: \(error.localizedDescription)")
                }
            }
        }
        
        // 所有文件加载完成后，在主线程执行复制
        dispatchGroup.notify(queue: .main) {
            if Self.verbose {
                os_log("\(self.t)✅ 所有文件加载完成，开始复制")
            }
            copy(droppedFiles)
        }
        
        return true
    }
}

// MARK: - Preview

#if os(macOS)
#Preview("App - Large") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 1000)
}

#Preview("App - Small") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 700)
}
#endif

#if os(iOS)
#Preview("iPhone") {
    ContentView()
    .inRootView()
}
#endif

