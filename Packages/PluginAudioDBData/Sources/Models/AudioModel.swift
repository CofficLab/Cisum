import AVFoundation
import CryptoKit
import Foundation
import CisumUIComponents

import OSLog
import SwiftData
import SwiftUI

/* 存储音频数据，尤其是将计算出来的属性存储下来 */

@Model
public final class AudioModel: SuperLog {
    public static let emoji = "🔔"
    public static let verbose = false

    @Transient let fileManager = FileManager.default
    @Transient var db: AudioRepo?

    // MARK: Properties

    // 新增字段记得设置默认值，否则低版本更新时崩溃

    @Attribute(.unique)
    public var url: URL
    public var order: Int
    public var isPlaceholder: Bool = false
    public var title: String = ""
    public var playCount: Int = 0
    public var size: Int64?
    public var identifierKey: String?
    public var contentType: String?
    public var hasCover: Bool?
    public var fileHash: String?
    public var isFolder: Bool = false

    public var verbose: Bool { Self.verbose }

    public var children: [AudioModel]? {
        if url == .applicationDirectory {
            return nil
        }

        return [AudioModel(.applicationDirectory)]
    }

    public init(_ url: URL,
         size: Int64? = nil,
         title: String? = nil,
         identifierKey: String? = nil,
         contentType: String? = nil,
         isFolder: Bool = false,
         order: Int? = nil
    ) {
        if Self.verbose {
            os_log("\(Self.i) -> \(url.lastPathComponent)")
            os_log("\(Self.i) Title: \(title ?? "")")
            os_log("\(Self.i) Type: \(contentType ?? "")")
            os_log("\(Self.i) Size: \(String(describing: size))")
        }

        self.url = url
        self.order = order ?? Self.makeRandomOrder()
        self.identifierKey = identifierKey
        self.contentType = contentType
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedTitle, !trimmedTitle.isEmpty {
            self.title = trimmedTitle
        } else {
            self.title = url.deletingPathExtension().lastPathComponent
        }

        if let size = size {
            self.size = size
        } else {
            self.size = Int64(url.getSize())
        }
    }

    public func setDB(_ db: AudioRepo?) {
        self.db = db
    }
}

// MARK: Order

public extension AudioModel {
    static func makeRandomOrder() -> Int {
        Int.random(in: 101 ... 500000000)
    }

    func randomOrder() {
        order = Self.makeRandomOrder()
    }
}

// MARK: ID

extension AudioModel: Identifiable {
    public var id: PersistentIdentifier { persistentModelID }
}

// MARK: Size

public extension AudioModel {
    func getFileSizeReadable() -> String {
        url.getSizeReadable()
    }
}

// MARK: Descriptor

public extension AudioModel {
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

    static var descriptorLast: FetchDescriptor<AudioModel> {
        var descriptor = FetchDescriptor<AudioModel>()
        descriptor.sortBy.append(.init(\.order, order: .reverse))
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
