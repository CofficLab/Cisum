import Foundation

struct FileItem: Identifiable, Hashable {
    let url: URL
    let level: Int
    var isExpanded: Bool
    var id: String { url.absoluteString }
    
    func children() throws -> [FileItem]? {
        guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            return nil
        }
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )
        
        return contents.map { FileItem(url: $0, level: level + 1, isExpanded: false) }
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
