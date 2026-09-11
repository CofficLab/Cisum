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
