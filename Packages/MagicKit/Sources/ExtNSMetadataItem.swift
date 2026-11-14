import Foundation

public extension NSMetadataItem {
    /// 文件名
    var fileName: String? {
        value(forAttribute: NSMetadataItemFSNameKey) as? String
    }
    
    /// 文件大小（字节）
    var fileSize: Int64? {
        value(forAttribute: NSMetadataItemFSSizeKey) as? Int64
    }
    
    /// 文件内容类型（UTI）
    var contentType: String? {
        value(forAttribute: NSMetadataItemContentTypeKey) as? String
    }
    
    /// 是否为目录
    var isDirectory: Bool {
        contentType == "public.folder"
    }
    
    /// 文件 URL
    var url: URL? {
        value(forAttribute: NSMetadataItemURLKey) as? URL
    }
    
    /// 是否为占位文件（未完全下载的文件）
    var isPlaceholder: Bool {
        guard let downloadingStatus = value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else {
            return false
        }
        // 只要不是 Current，就认为是占位符或未就绪
        return downloadingStatus != NSMetadataUbiquitousItemDownloadingStatusCurrent
    }
    
    /// 下载进度（0-1）
    var downloadProgress: Double {
        URLDownloadProgressPolicy.normalizedFraction(
            percentDownloaded: value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double
        )
    }
    
    /// 是否已上传完成
    var isUploaded: Bool {
        (value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double ?? 0.0) >= 99.9
    }
    
    /// 文件是否已下载完成
    var isDownloaded: Bool {
        // 先检查进度（进度达到 100% 视为已下载，这比状态更新快）
        if downloadProgress >= 1.0 {
            return true
        }

        guard let downloadingStatus = value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else {
            return true // 本地文件或无法获取状态，视为已下载
        }
        return downloadingStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent
    }
    
    /// 文件是否正在下载
    var isDownloading: Bool {
        guard let downloadingStatus = value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else {
            return false
        }
        return downloadingStatus == "NSMetadataUbiquitousItemDownloadingStatusDownloading"
    }
    
    /// 打印所有属性（调试用）
    func debugPrint() {
        attributes.forEach { key in
            var value = self.value(forAttribute: key) as? String ?? ""
            
            if key == NSMetadataItemURLKey {
                value = (self.value(forAttribute: key) as? URL)?.path ?? "x"
            }
            
            if key == NSMetadataItemFSSizeKey {
                value = (self.value(forAttribute: NSMetadataItemFSSizeKey) as? Int)?.description ?? "x"
            }
            
            print("    \(key):\(value)")
        }
    }
}

// MARK: - Hashable
extension NSMetadataItem {
    override public var hash: Int {
        url?.hashValue ?? 0
    }
}
