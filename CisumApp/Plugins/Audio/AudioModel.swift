import AVFoundation
import CryptoKit
import Foundation
import MagicKit

import OSLog
import SwiftData
import SwiftUI

/* 存储音频数据，尤其是将计算出来的属性存储下来 */

@Model
final class AudioModel: SuperLog {
    static let emoji = "🔔"
    static let verbose = false

    @Transient let fileManager = FileManager.default
    @Transient var db: AudioRepo?

    // MARK: Properties

    // 新增字段记得设置默认值，否则低版本更新时崩溃

    @Attribute(.unique)
    var url: URL
    var order: Int
    var isPlaceholder: Bool = false
    var title: String = ""
    var playCount: Int = 0
    var size: Int64?
    var identifierKey: String?
    var contentType: String?
    var hasCover: Bool?
    var fileHash: String?
    var isFolder: Bool = false

    var verbose: Bool { Self.verbose }

    var children: [AudioModel]? {
        if url == .applicationDirectory {
            return nil
        }

        return [AudioModel(.applicationDirectory)]
    }

    init(_ url: URL,
         size: Int64? = nil,
         title: String? = nil,
         identifierKey: String? = nil,
         contentType: String? = nil,
         isFolder: Bool = false
    ) {
        if Self.verbose {
            os_log("\(Self.i) -> \(url.lastPathComponent)")
            print(" Title: \(title ?? "")")
            print(" Type: \(contentType ?? "")")
            print(" Size: \(String(describing: size))")
        }

        self.url = url
        self.order = Self.makeRandomOrder()
        self.identifierKey = identifierKey
        self.contentType = contentType
        self.title = url.deletingPathExtension().lastPathComponent

        if let size = size {
            self.size = size
        } else {
            self.size = Int64(url.getSize())
        }
    }

    func setDB(_ db: AudioRepo?) {
        self.db = db
    }
}

// MARK: Order

extension AudioModel {
    static func makeRandomOrder() -> Int {
        Int.random(in: 101 ... 500000000)
    }

    func randomOrder() {
        order = Self.makeRandomOrder()
    }
}

// MARK: ID

extension AudioModel: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}

// MARK: Size

extension AudioModel {
    func getFileSizeReadable() -> String {
        url.getSizeReadable()
    }
}

// MARK: Descriptor

extension AudioModel {
    static var descriptorOrderAsc: FetchDescriptor<AudioModel> {
        var descriptor = FetchDescriptor<AudioModel>()
        descriptor.sortBy.append(.init(\.order, order: .forward))
        return descriptor
    }

    static var descriptorOrderDesc: FetchDescriptor<AudioModel> {
        var descriptor = FetchDescriptor<AudioModel>()
        descriptor.sortBy.append(.init(\.order, order: .reverse))
        return descriptor
    }

    static var descriptorFirst: FetchDescriptor<AudioModel> {
        var descriptor = FetchDescriptor<AudioModel>()
        descriptor.sortBy.append(.init(\.order, order: .forward))
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func descriptorPrev(order: Int) -> FetchDescriptor<AudioModel> {
        var descriptor = FetchDescriptor<AudioModel>()
        descriptor.sortBy.append(.init(\.order, order: .reverse))
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate {
            $0.order < order
        }
        return descriptor
    }

    static func descriptorNext(order: Int) -> FetchDescriptor<AudioModel> {
        var descriptor = FetchDescriptor<AudioModel>()
        descriptor.sortBy.append(.init(\.order, order: .forward))
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate {
            $0.order > order
        }
        return descriptor
    }

    static let descriptorAll = FetchDescriptor(predicate: #Predicate<AudioModel> { _ in
        true
    }, sortBy: [
        SortDescriptor(\.order, order: .forward),
    ])

    static let descriptorNotFolder = FetchDescriptor(predicate: predicateNotFolder, sortBy: [
        SortDescriptor(\.order, order: .forward),
    ])

    static let predicateNotFolder = #Predicate<AudioModel> { audio in
        audio.isFolder == false
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
