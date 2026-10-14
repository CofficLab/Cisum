import ProviderBook
import SwiftUI

/// 有声书仓库设置页依赖：通过本插件的书库能力访问书籍数据。
public struct BookDBDependencies: @unchecked Sendable {
    public var bookLibrary: (any BookLibraryCapability)?
    public var bookDisk: @MainActor @Sendable () -> URL?

    public init(
        bookLibrary: (any BookLibraryCapability)?,
        bookDisk: @escaping @MainActor @Sendable () -> URL?
    ) {
        self.bookLibrary = bookLibrary
        self.bookDisk = bookDisk
    }

    public static let empty = BookDBDependencies(
        bookLibrary: nil,
        bookDisk: { nil }
    )
}