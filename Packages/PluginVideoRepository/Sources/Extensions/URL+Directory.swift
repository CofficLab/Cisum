import Foundation

extension URL {
    /// 确保路径是一个存在的目录；同名文件会被替换为目录。
    func ensureDirectory() throws -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue {
            try FileManager.default.removeItem(at: self)
        } else if (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil {
            try FileManager.default.removeItem(at: self)
        }

        try FileManager.default.createDirectory(
            at: self,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return self
    }
}
