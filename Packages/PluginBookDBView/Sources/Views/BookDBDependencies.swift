import ProviderBook
import ProviderBook
import SwiftUI

/// 有声书仓库设置页依赖：通过 Provider 访问书籍数据。
public struct BookDBDependencies: @unchecked Sendable {
    public var bookProvider: (any BookDatabaseProviding)?
    public var bookDisk: @MainActor @Sendable () -> URL?

    public init(
        bookProvider: (any BookDatabaseProviding)?,
        bookDisk: @escaping @MainActor @Sendable () -> URL?
    ) {
        self.bookProvider = bookProvider
        self.bookDisk = bookDisk
    }

    public static let empty = BookDBDependencies(
        bookProvider: nil,
        bookDisk: { nil }
    )
}
