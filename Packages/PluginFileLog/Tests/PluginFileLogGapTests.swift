import Testing
@testable import PluginFileLog
import Foundation

/// 补充测试用例 - 对应 TestPlan.md 中标记为 ❌ 缺失的测试
@Suite
struct PluginFileLogGapTests {
    
    // MARK: - 插件元数据测试
    
    /// TC-17: contributesMetadata 返回正确元数据
    @Test @MainActor
    func pluginMetadataIsCorrect() {
        let plugin = FileLogPlugin.shared
        let metadata = plugin.metadata
        
        #expect(metadata.id == "FileLogPlugin")
        #expect(metadata.name == "File Log")
        #expect(!metadata.description.isEmpty)
        #expect(metadata.version == "1.0.0")
        #expect(metadata.category == .system)
        #expect(metadata.stage == .stable)
        #expect(metadata.policy == .disabled)
        #expect(metadata.permissions.isEmpty)
    }
    
    // MARK: - 日志轮转序号测试
    
    /// TC-19: 多个文件已存在时生成正确序号
    @Test
    func rotationGeneratesCorrectSequenceWithMultipleFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // 创建已存在的文件
        let file1 = tempDir.appendingPathComponent("test.log")
        let file2 = tempDir.appendingPathComponent("test 2.log")
        FileManager.default.createFile(atPath: file1.path, contents: nil)
        FileManager.default.createFile(atPath: file2.path, contents: nil)
        
        // 生成新文件名
        let baseName = "test"
        let newURL = FileLogRotation.uniqueLogFileURL(baseName: baseName, in: tempDir)
        
        // 应该生成 test 3.log
        #expect(newURL.lastPathComponent == "test 3.log")
    }
    
    /// TC-19b: 更多序号测试
    @Test
    func rotationGeneratesCorrectSequenceWithManyFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // 创建多个日志文件
        for i in 1...5 {
            let fileName = i == 1 ? "log.log" : "log \(i).log"
            let file = tempDir.appendingPathComponent(fileName)
            FileManager.default.createFile(atPath: file.path, contents: nil)
        }
        
        // 生成新文件名
        let newURL = FileLogRotation.uniqueLogFileURL(baseName: "log", in: tempDir)
        
        // 应该生成 log 6.log
        #expect(newURL.lastPathComponent == "log 6.log")
    }
    
    /// TC-19c: 空目录测试
    @Test
    func rotationInEmptyDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // 生成新文件名
        let newURL = FileLogRotation.uniqueLogFileURL(baseName: "empty", in: tempDir)
        
        // 应该生成 empty.log
        #expect(newURL.lastPathComponent == "empty.log")
    }
}
