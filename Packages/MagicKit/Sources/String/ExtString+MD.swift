import Foundation
import OSLog

extension String {
    /// 将字符串保存为 Markdown 文件
    /// - Parameter url: Markdown 文件的保存路径
    /// - Throws: 文件操作过程中可能发生的错误
    ///   - 文件写入错误
    ///   - 文件路径无效
    public func saveMarkdown(_ url: URL) throws {
        try self.replaceImageSrcWithRelativePath(url).toMarkdown().saveToFile(url)
    }
    
    /// 将 HTML 格式的字符串转换为 Markdown 格式
    /// - Returns: 转换后的 Markdown 文本
    /// - Note: 支持以下 HTML 元素的转换：
    ///   - 标题 (h1-h6)
    ///   - 段落 (p)
    ///   - 链接 (a)
    ///   - 图片 (img)
    ///   - 粗体 (strong)
    ///   - 斜体 (em)
    ///   - 无序列表 (ul/li)
    ///   - 有序列表 (ol/li)
    public func toMarkdown() -> String {
        var markdown = self
        
        // 替换标题（h1-h6）
        for i in 1...6 {
            let tag = "h\(i)"
            let markdownHeader = String(repeating: "#", count: i) + " "
            let pattern = "<\(tag)(?:\\s+[^>]*?)?>(.*?)</\(tag)>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            let matches = regex.matches(in: markdown, options: [], range: NSRange(location: 0, length: markdown.utf16.count))
            
            for match in matches.reversed() {
                let range = match.range(at: 1)
                let headerContent = (markdown as NSString).substring(with: range)
                
                // 清理内容中的<strong>标签
                let cleanedHeaderContent = headerContent
                    .replacingOccurrences(of: "<strong[^>]*?>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "</strong>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                markdown = markdown.replacingOccurrences(
                    of: "<\(tag)(?:\\s+[^>]*?)?>\(headerContent)</\(tag)>",
                    with: "\(markdownHeader)\(cleanedHeaderContent)\n\n",
                    options: .regularExpression
                )
            }
        }
        
        // 替换段落
        markdown = markdown.replacingOccurrences(of: "<p>", with: "")
        markdown = markdown.replacingOccurrences(of: "</p>", with: "\n\n")
        
        // 替换链接
        let linkPattern = "<a href=\"(.*?)\">(.*?)</a>"
        if let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: []) {
            let linkRange = NSRange(location: 0, length: markdown.utf16.count)
            markdown = linkRegex.stringByReplacingMatches(in: markdown, options: [], range: linkRange, withTemplate: "[$2]($1)")
        }
        
        // 替换 img 标签
        let imgPattern = "<img[^>]*?src=\"(.*?)\"(?:\\s+alt=\"(.*?)\")?[^>]*?/?>"
        if let imgRegex = try? NSRegularExpression(pattern: imgPattern, options: []) {
            let imgRange = NSRange(location: 0, length: markdown.utf16.count)
            markdown = imgRegex.stringByReplacingMatches(in: markdown, options: [], range: imgRange, withTemplate: "![$2]($1)\n\n")
        }
        
        // 替换其他标签
        markdown = markdown.replacingOccurrences(of: "<strong[^>]*?>", with: "**", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "</strong>", with: "**")
        markdown = markdown.replacingOccurrences(of: "<em>", with: "*")
        markdown = markdown.replacingOccurrences(of: "</em>", with: "*")
        markdown = markdown.replacingOccurrences(of: "<ul>", with: "")
        markdown = markdown.replacingOccurrences(of: "</ul>", with: "")
        markdown = markdown.replacingOccurrences(of: "<ol>", with: "")
        markdown = markdown.replacingOccurrences(of: "</ol>", with: "")
        markdown = markdown.replacingOccurrences(of: "<li>", with: "- ")
        markdown = markdown.replacingOccurrences(of: "</li>", with: "\n")
        
        // 移除剩余的 HTML 标签
        markdown = markdown.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // 去除多余的空行
        //
        // 单次 `replacingOccurrences(of: "\n\n\n", with: "\n\n")` 只能收敛**一层**：
        // 四个连续换行里两处 `\n\n\n` 相互重叠，替换后仍剩 `\n\n\n`。
        // 因此改用正则一次性把「三个及以上连续换行」收敛成两个。
        if let blankLineRegex = try? NSRegularExpression(pattern: "\n{3,}", options: []) {
            let range = NSRange(location: 0, length: markdown.utf16.count)
            markdown = blankLineRegex.stringByReplacingMatches(
                in: markdown,
                options: [],
                range: range,
                withTemplate: "\n\n"
            )
        }

        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 将 HTML 字符串转换为 Markdown 并保存，同时处理 base64 格式的图片
    /// - Parameters:
    ///   - markdownPath: Markdown 文件的保存路径
    ///   - imagesPath: 图片文件的保存目录路径
    /// - Throws: 文件操作或图片处理过程中的错误
    public func saveHTMLToMarkdown(_ markdownPath: URL, imagesPath: URL) throws {
        var htmlContent = self
        
        // 创建图片保存目录（如果不存在）
        try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
        
        // 匹配 base64 格式的图片
        let pattern = "<img[^>]*?src=\"data:image/(.*?);base64,(.*?)\"[^>]*?>"
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: htmlContent, options: [], range: NSRange(location: 0, length: htmlContent.utf16.count))
        
        // 处理每个 base64 图片
        for (index, match) in matches.reversed().enumerated() {
            let nsString = htmlContent as NSString
            let fullMatch = nsString.substring(with: match.range)
            
            // 提取图片格式和 base64 数据
            let formatRange = match.range(at: 1)
            let base64Range = match.range(at: 2)
            let format = nsString.substring(with: formatRange)
            let base64Data = nsString.substring(with: base64Range)
            
            // 生成图片文件名
            let fileName = "image_\(index).\(format)"
            let imageURL = imagesPath.appendingPathComponent(fileName)
            
            // 将 base64 转换为数据并保存为图片文件
            if let imageData = Data(base64Encoded: base64Data) {
                try imageData.write(to: imageURL)
                
                // 替换 HTML 中的 base64 为相对路径
                let relativePath = "images/\(fileName)"
                htmlContent = htmlContent.replacingOccurrences(
                    of: fullMatch,
                    with: "<img src=\"\(relativePath)\">"
                )
            }
        }
        
        // 将处理后的 HTML 转换为 Markdown 并保存
        try htmlContent.saveMarkdown(markdownPath)
    }
}
