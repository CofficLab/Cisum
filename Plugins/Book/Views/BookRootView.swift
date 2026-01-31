import Foundation
import MagicKit
import MagicPlayMan
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

class BookRepoState: ObservableObject {
    @Published var repo: BookRepo? = nil
    @Published var container: ModelContainer? = nil
    @Published var error: Error? = nil
    @Published var isLoading: Bool = true
}

struct BookRootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "🏓" }
    nonisolated static var verbose: Bool { false }

    @EnvironmentObject var man: PlayMan
    @EnvironmentObject var p: PluginProvider

    private var content: Content
    @StateObject private var bookRepoState = BookRepoState()

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if let error = bookRepoState.error {
                error.makeView()
            } else if bookRepoState.isLoading {
                ProgressView("正在初始化...")
            } else if let container = bookRepoState.container, let repo = bookRepoState.repo {
                ZStack {
                    content
                }
                .modelContainer(container)
                .environmentObject(repo)
                .onStorageLocationChanged {
                    self.initAll()
                }
            } else {
                Text("初始化失败")
            }
        }
        .onAppear {
            self.initAll()
        }
    }
}

// MARK: - Action

extension BookRootView {
    private func initAll() {
        if Self.verbose {
            os_log("\(self.t)InitAll")
        }
        bookRepoState.isLoading = true
        bookRepoState.error = nil

        Task {
            do {
                // 1. 初始化 Container
                let container = try BookConfig.getContainer()
                if Self.verbose {
                    os_log("\(self.t)🎉 Container 初始化成功")
                }

                // 2. 获取 Disk
                guard let disk = BookPlugin.getBookDisk() else {
                    await MainActor.run {
                        self.setBookRepoState(nil, container: nil, error: BookPluginError.initialization(reason: "Disk 未找到"))
                    }
                    return
                }
                if Self.verbose {
                    os_log("\(self.t)🎉 Disk 获取成功: \(disk.shortPath())")
                }

                // 3. 初始化 BookRepo
                let db = BookDB(container, reason: self.className)
                let repo = try BookRepo(disk: disk, db: db)

                await MainActor.run {
                    self.setBookRepoState(repo, container: container)
                    if Self.verbose {
                        os_log("\(self.t)🎉 BookRepo 初始化成功")
                    }
                }
            } catch {
                await MainActor.run {
                    self.setBookRepoState(nil, container: nil, error: error)
                    os_log("❌初始化失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Setter

extension BookRootView {
    @MainActor private func setBookRepoState(_ repo: BookRepo?, container: ModelContainer?, error: Error? = nil) {
        bookRepoState.repo = repo
        bookRepoState.container = container
        bookRepoState.error = error
        bookRepoState.isLoading = false
    }
}

// MARK: - Event Handler

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
            .frame(width: 600, height: 600)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
    .inRootView()
    }
#endif
