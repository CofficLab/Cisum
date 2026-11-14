import Foundation
import ProviderBook
import SwiftUI

/// 有声书仓库视图依赖：数据访问统一通过本插件的书库能力注入。
public struct BookDBViewDependencies: @unchecked Sendable {
    let dbRoot: URL
    let bookDisk: URL?
    let bookLibrary: (any BookLibraryCapability)?
    let isDesktop: Bool
    let isNotDesktop: Bool

    public init(
        dbRoot: URL,
        bookDisk: URL?,
        bookLibrary: (any BookLibraryCapability)?,
        isDesktop: Bool,
        isNotDesktop: Bool
    ) {
        self.dbRoot = dbRoot
        self.bookDisk = bookDisk
        self.bookLibrary = bookLibrary
        self.isDesktop = isDesktop
        self.isNotDesktop = isNotDesktop
    }
}