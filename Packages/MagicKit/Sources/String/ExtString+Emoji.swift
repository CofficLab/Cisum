import Foundation

extension String {
    /// 根据字符串内容生成相关的 emoji 并添加到原始内容前
    /// - Returns: emoji + 原始内容的组合字符串
    public var withContextEmoji: String {
        let emoji = self.generateContextEmoji()
        return "\(emoji) \(self)"
    }

    /// 根据字符串内容分析并生成相关的 emoji
    /// - Returns: 相关的 emoji
    public func generateContextEmoji() -> String {
        let lowercased = self.lowercased()

        // 定义一个包含所有匹配的元组，按优先级排序
        let emojiMappings: [(String, String)] = [
            ("archive", "💼"), ("归档", "💼"),
            ("appear", "👀"), ("出现", "👀"),
            ("backup", "💼"), ("备份", "💼"),
            ("bypass", "⏭️"), ("绕过", "⏭️"),
            ("click", "👆"), ("点击", "👆"),
            ("complete", "✅"), ("完成", "✅"),
            ("config", "🚩"), ("配置", "🚩"),
            ("crash", "❌"), ("崩溃", "❌"),
            ("data", "💾"), ("数据", "💾"),
            ("debug", "🔍"), ("调试", "🔍"),
            ("display", "👀"), ("展示", "👀"),
            ("done", "✅"), ("完成", "✅"),
            ("error", "❌"), ("错误", "❌"),
            ("fail", "❌"), ("失败", "❌"),
            ("finish", "✅"), ("结束", "✅"),
            ("http", "🌐"), ("HTTP", "🌐"),
            ("ignore", "⏭️"), ("忽略", "⏭️"),
            ("init", "🚩"), ("初始化", "🚩"),
            ("load", "💾"), ("加载", "💾"),
            ("manager", "👔"), ("经理", "👔"),
            ("merge", "🔗"), ("合并", "🔗"),
            ("memory", "📊"), ("内存", "📊"),
            ("modify", "🍋"), ("修改", "🍋"),
            ("network", "🌐"), ("网络", "🌐"),
            ("notification", "🔔"), ("通知", "🔔"),
            ("ok", "✅"), ("好的", "✅"),
            ("performance", "📊"), ("性能", "📊"),
            ("plugin", "🔌"), ("插件", "🔌"),
            ("push", "⬆️"), ("推送", "⬆️"),
            ("ready", "✅"), ("准备好", "✅"),
            ("save", "💾"), ("保存", "💾"),
            ("set", "⚙️"), ("设置", "⚙️"),
            ("show", "👀"), ("显示", "👀"),
            ("skip", "⏭️"), ("跳过", "⏭️"),
            ("synchronize", "🔄"), ("同步", "🔄"),
            ("tap", "👆"), ("轻触", "👆"),
            ("test", "🔍"), ("测试", "🔍"),
            ("update", "🍋"), ("更新", "🍋"),
            ("uuid", "🆔"), ("唯一标识符", "🆔"),
            ("visible", "👀"), ("可见", "👀"),
            ("warn", "⚠️"), ("警告", "⚠️"),
            ("warning", "⚠️"), ("警告", "⚠️"),
        ]

        // 遍历所有映射，优先返回匹配的 emoji
        for (keyword, emoji) in emojiMappings {
            if lowercased.hasPrefix(keyword) || lowercased.contains(keyword) {
                return emoji
            }
        }

        // 默认返回一个通用的 emoji
        return "📝"
    }
}
