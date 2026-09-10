import Foundation
import ProviderBook
import ProviderBook
import SwiftUI

/// 有声书仓库视图依赖：数据访问统一通过 Kernel 注册的 Provider 注入。
public struct BookDBViewDependencies: @unchecked Sendable {
    let dbRoot: URL
    let bookDisk: URL?
    let bookProvider: (any BookDatabaseProviding)?
    let isDesktop: Bool
    let isNotDesktop: Bool

    public init(
        dbRoot: URL,
        bookDisk: URL?,
        bookProvider: (any BookDatabaseProviding)?,
        isDesktop: Bool,
        isNotDesktop: Bool
    ) {
        self.dbRoot = dbRoot
        self.bookDisk = bookDisk
        self.bookProvider = bookProvider
        self.isDesktop = isDesktop
        self.isNotDesktop = isNotDesktop
    }
}

private struct BookDBViewDependenciesKey: EnvironmentKey {
    static let defaultValue = BookDBViewDependencies(
        dbRoot: FileManager.default.temporaryDirectory,
        bookDisk: nil,
        bookProvider: nil,
        isDesktop: false,
        isNotDesktop: true
    )
}

extension EnvironmentValues {
    var bookDBViewDependencies: BookDBViewDependencies {
        get { self[BookDBViewDependenciesKey.self] }
        set { self[BookDBViewDependenciesKey.self] = newValue }
    }

    var bookDBImportAction: @MainActor @Sendable () -> Void {
        get { self[BookDBImportActionKey.self] }
        set { self[BookDBImportActionKey.self] = newValue }
    }
}

private struct BookDBImportActionKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

public extension View {
    func bookDBViewDependencies(_ dependencies: BookDBViewDependencies) -> some View {
        environment(\.bookDBViewDependencies, dependencies)
    }
}
