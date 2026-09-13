import Foundation

public extension URL {
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
