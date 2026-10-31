import Foundation
import Testing
@testable import MagicKit

// MARK: - HTML → Markdown

/// HTML → Markdown 是说明书与外部笔记落盘的前置转换。
///
/// 转换结果会被用户直接阅读，因此必须锁定：标题层级、段落、链接、图片、
/// 强调、列表的语义都要稳定；无对应语义的残留标签必须被清掉。
@Suite("HTML 转 Markdown")
struct HTMLToMarkdownTests {
    @Test("各级标题转换为对应数量的井号")
    func headingsConvertToHashLevels() {
        #expect("<h1>Title</h1>".toMarkdown() == "# Title")
        #expect("<h2>Title</h2>".toMarkdown() == "## Title")
        #expect("<h3>Title</h3>".toMarkdown() == "### Title")
        #expect("<h6>Title</h6>".toMarkdown() == "###### Title")
    }

    @Test("带属性的标题同样被转换")
    func headingsWithAttributesConvert() {
        #expect("<h2 class=\"x\">Title</h2>".toMarkdown() == "## Title")
    }

    @Test("标题内的强调标签被清理")
    func headingStripsStrongTags() {
        #expect("<h1><strong>Title</strong></h1>".toMarkdown() == "# Title")
    }

    @Test("链接转换为 Markdown 链接语法")
    func linksConvert() {
        #expect(
            "<a href=\"https://example.com\">more</a>".toMarkdown()
                == "[more](https://example.com)"
        )
    }

    @Test("图片转换为 Markdown 图片语法")
    func imagesConvert() {
        let result = "<img src=\"cover.png\" alt=\"Cover\">".toMarkdown()
        #expect(result.contains("![Cover](cover.png)"))
    }

    @Test("无 alt 的图片仍保留图片语法")
    func imageWithoutAltKeepsSyntax() {
        let result = "<img src=\"cover.png\">".toMarkdown()
        #expect(result.contains("(cover.png)"))
        #expect(result.contains("!"))
    }

    @Test("粗体与斜体转换为强调符号")
    func emphasisConverts() {
        #expect("**bold**".toMarkdown() == "**bold**")
        #expect("*italic*".toMarkdown() == "*italic*")
    }

    @Test("无序列表转换为短横线列表")
    func unorderedListConverts() {
        let result = "<ul><li>a</li><li>b</li></ul>".toMarkdown()
        #expect(result.contains("- a"))
        #expect(result.contains("- b"))
    }

    @Test("有序列表转换为短横线列表")
    func orderedListConverts() {
        let result = "<ol><li>first</li></ol>".toMarkdown()
        #expect(result.contains("- first"))
    }

    @Test("段落标签被移除")
    func paragraphTagsRemoved() {
        let result = "<p>Hello</p>".toMarkdown()
        #expect(result == "Hello")
    }

    @Test("未知的残留 HTML 标签被清除")
    func residualTagsAreStripped() {
        let result = "<div><span class=\"x\">Hello</span></div>".toMarkdown()
        #expect(result == "Hello")
    }

    @Test("结果首尾没有多余空白")
    func resultIsTrimmed() {
        #expect("<p>Hello</p>".toMarkdown() == "Hello")
        #expect("   <p>Hello</p>   ".toMarkdown() == "Hello")
    }

    @Test("连续空行被收敛为单个空行")
    func consecutiveBlankLinesCollapse() {
        let result = "<p>a</p><p></p><p>b</p>".toMarkdown()
        #expect(!result.contains("\n\n\n"))
    }

    @Test("空 HTML 得到空串")
    func emptyHTMLGivesEmptyMarkdown() {
        #expect("".toMarkdown().isEmpty)
        #expect("   ".toMarkdown().isEmpty)
    }
}

// MARK: - Markdown 落盘

@Suite("Markdown 落盘")
struct MarkdownPersistenceTests {
    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("saveMarkdown 把转换结果写入目标文件")
    func saveMarkdownWritesFile() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("note.md")
        try "<h1>Title</h1><p>Body</p>".saveMarkdown(target)

        let written = try String(contentsOf: target, encoding: .utf8)
        #expect(written.contains("# Title"))
        #expect(written.contains("Body"))
    }

    @Test("saveMarkdown 会创建缺失的父目录")
    func saveMarkdownCreatesParentDirectory() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("deeper", isDirectory: true)
            .appendingPathComponent("note.md")
        try "<p>Body</p>".saveMarkdown(target)

        #expect(FileManager.default.fileExists(atPath: target.path))
    }

    @Test("saveHTMLToMarkdown 把 base64 图片落盘并改写为相对路径")
    func saveHTMLToMarkdownExtractsBase64Images() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        // 1x1 透明 PNG。
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        let html = "<p>See image</p><img src=\"data:image/png;base64,\(base64)\">"

        let markdownPath = root.appendingPathComponent("out.md")
        let imagesPath = root.appendingPathComponent("images")
        try html.saveHTMLToMarkdown(markdownPath, imagesPath: imagesPath)

        // 图片目录里应有落盘的文件。
        let files = try FileManager.default.contentsOfDirectory(atPath: imagesPath.path)
        #expect(files.contains { $0.hasSuffix(".png") })

        // Markdown 里的引用应改写为相对路径，且不再残留 base64 数据。
        let written = try String(contentsOf: markdownPath, encoding: .utf8)
        #expect(written.contains("images/"))
        #expect(!written.contains("base64,"))
        #expect(written.contains("See image"))
    }

    @Test("saveHTMLToMarkdown 对没有 base64 图片的 HTML 仍能落盘")
    func saveHTMLToMarkdownWithoutImages() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let markdownPath = root.appendingPathComponent("plain.md")
        let imagesPath = root.appendingPathComponent("images")
        try "<h2>Plain</h2>".saveHTMLToMarkdown(markdownPath, imagesPath: imagesPath)

        let written = try String(contentsOf: markdownPath, encoding: .utf8)
        #expect(written.contains("## Plain"))
    }
}

// MARK: - 内嵌图片路径改写

@Suite("HTML 内嵌图片路径改写")
struct EmbeddedImageRewriteTests {
    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("base64 图片被写入 images 子目录并改写引用")
    func base64ImageIsExtractedAndRewritten() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        let html = "<img src=\"data:image/png;base64,\(base64)\">"

        let target = root.appendingPathComponent("doc.html")
        let rewritten = html.replaceImageSrcWithRelativePath(target)

        #expect(!rewritten.contains("base64,"))
        #expect(rewritten.contains("./images/"))

        let imagesDir = root.appendingPathComponent("images", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: imagesDir.path))
    }

    @Test("文件名中的空格被替换为下划线")
    func fileNamePrefixSanitizesSpaces() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        let html = "<img src=\"data:image/png;base64,\(base64)\">"

        let target = root.appendingPathComponent("My Document.html")
        let rewritten = html.replaceImageSrcWithRelativePath(target)

        #expect(rewritten.contains("My_Document_1.png"))
    }

    @Test("没有 base64 图片时原样返回")
    func htmlWithoutBase64IsUnchanged() {
        let html = "<p>No images here</p>"
        let target = URL(fileURLWithPath: "/tmp/doc.html")
        #expect(html.replaceImageSrcWithRelativePath(target) == html)
    }
}
