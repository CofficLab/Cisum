import Foundation
import MagicKit

/// 列表项文件大小的读取、缓存与展示策略。
///
/// 原先这些类型住在 `Views/AudioItemView.swift`，但缓存与策略并非视图职责：
/// `AudioListViewModel` 在删除 / 全量刷新时也要操作同一个缓存。移入 `Models/`
/// 以符合目录规范，并让「文件大小是插件状态」这一事实显式化。
enum AudioItemFileSizeLoadPolicy {
    static func shouldApplySize(currentURL: URL, requestedURL: URL) -> Bool {
        representsSameFile(currentURL, requestedURL)
    }

    private static func representsSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.isSameFileLocation(as: rhs)
    }
}

enum AudioItemFileSizeReadPolicy {
    static func fileSize(from attributes: [FileAttributeKey: Any]) -> Int64? {
        if let number = attributes[.size] as? NSNumber {
            return normalizedSize(number)
        }

        if let size = attributes[.size] as? Int {
            return normalizedSize(Int64(size))
        }

        if let size = attributes[.size] as? Int64 {
            return normalizedSize(size)
        }

        if let size = attributes[.size] as? UInt64 {
            guard size <= UInt64(Int64.max) else { return Int64.max }
            return Int64(size)
        }

        return nil
    }

    /// 读取磁盘上的真实字节数。
    ///
    /// iCloud「优化存储」下的占位文件会读到 `0`（或读不到），因此**读到的 0 不能
    /// 当作可信值缓存**：文件下载完成后大小会变化，而缓存会一直返回旧值。
    static func currentFileSize(for url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return fileSize(from: attributes)
    }

    private static func normalizedSize(_ size: Int64) -> Int64 {
        max(size, 0)
    }

    private static func normalizedSize(_ number: NSNumber) -> Int64 {
        if number.compare(NSNumber(value: 0)) == .orderedAscending {
            return 0
        }

        if number.compare(NSNumber(value: Int64.max)) == .orderedDescending {
            return Int64.max
        }

        return number.int64Value
    }
}

enum AudioItemFileSizeDisplayState: Equatable {
    case loading
    case unavailable
    case size(Int64)
}

enum AudioItemFileSizeDisplayPolicy {
    static func state(fileSize: Int64?, isUnavailable: Bool) -> AudioItemFileSizeDisplayState {
        if let fileSize {
            return .size(fileSize)
        }

        return isUnavailable ? .unavailable : .loading
    }
}

/// 文件大小缓存（按文件身份）。
///
/// ## 为什么不缓存「读不到」的结果
///
/// iCloud 占位文件在下载完成前读不到真实大小。若把 `nil` 也缓存下来，条目在下载
/// 完成后仍会一直显示 `Unavailable`——因为没有任何信号能让它重读。改为**不缓存失败**：
/// 失败保持「加载中」语义，直到某次读取成功或用户离开该条目。
@MainActor
enum AudioItemFileSizeCache {
    private struct Entry {
        let size: Int64?
    }

    private static var entries: [String: Entry] = [:]

    static func cachedSize(for url: URL) -> Int64?? {
        let key = cacheKey(for: url)
        guard let entry = entries[key] else {
            return nil
        }
        return .some(entry.size)
    }

    /// 缓存一次读取结果。
    ///
    /// - Parameter size: `nil`（读取失败）**不会**写入缓存——失败必须可重试，
    ///   否则 iCloud 文件下载完成后永远显示「不可用」。
    static func store(_ size: Int64?, for url: URL) {
        guard let size else { return }
        let key = cacheKey(for: url)
        entries[key] = Entry(size: size)
    }

    static func remove(_ urls: [URL]) {
        let keys = urls.map(cacheKey(for:))
        for key in keys {
            entries.removeValue(forKey: key)
        }
    }

    static func removeAll() {
        entries.removeAll()
    }

    private static func cacheKey(for url: URL) -> String {
        AudioListFileIdentity.canonicalIdentity(for: url)
    }
}