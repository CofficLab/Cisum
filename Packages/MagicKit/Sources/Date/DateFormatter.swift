import Foundation

/// DateComponentsFormatter 的扩展，提供预配置的时间格式化器
public extension DateComponentsFormatter {
    /// 缩写格式的时间格式化器
    ///
    /// 此格式化器配置为：
    /// - 显示小时、分钟和秒钟
    /// - 使用缩写样式（如：2h 30m 15s）
    ///
    /// # 示例
    /// ```swift
    /// let interval: TimeInterval = 9015 // 2小时30分15秒
    /// let formatted = DateComponentsFormatter.abbreviated.string(from: interval)
    /// print(formatted) // 输出: "2h 30m 15s"
    /// ```
    static let abbreviated: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    /// 位置格式的时间格式化器
    ///
    /// 此格式化器配置为：
    /// - 仅显示分钟和秒钟
    /// - 使用位置样式（如：04:30）
    /// - 对短于两位的数字进行补零
    ///
    /// 适用于：
    /// - 音频播放时长显示
    /// - 视频播放时长显示
    /// - 倒计时显示
    ///
    /// # 示例
    /// ```swift
    /// let interval: TimeInterval = 270 // 4分30秒
    /// let formatted = DateComponentsFormatter.positional.string(from: interval)
    /// print(formatted) // 输出: "04:30"
    /// ```
    static let positional: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    /// 相对时间格式化器
    ///
    /// 此格式化器配置为：
    /// - 使用相对日期时间格式
    /// - 自动选择合适的时间单位
    /// - 本地化显示
    ///
    /// # 示例
    /// ```swift
    /// let pastDate = Date().addingTimeInterval(-3600) // 1小时前
    /// let formatted = DateComponentsFormatter.relative.string(from: pastDate, to: Date())
    /// print(formatted) // 输出: "1 hour ago" 或本地化等效文本
    /// ```
    static let relative: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.year, .month, .weekOfMonth, .day, .hour, .minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        return formatter
    }()
}

/// RelativeDateTimeFormatter 的扩展，提供预配置的相对时间格式化器
@available(iOS 13.0, macOS 10.15, *)
public extension RelativeDateTimeFormatter {
    /// 标准相对时间格式化器
    ///
    /// 此格式化器配置为：
    /// - 使用数字样式（如："2小时前"）
    /// - 自动本地化
    ///
    /// # 示例
    /// ```swift
    /// let pastDate = Date().addingTimeInterval(-7200) // 2小时前
    /// let formatted = RelativeDateTimeFormatter.standard.localizedString(for: pastDate, relativeTo: Date())
    /// print(formatted) // 输出: "2小时前" 或其他语言的等效文本
    /// ```
    nonisolated(unsafe) static let standard: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        return formatter
    }()
    
    /// 简短相对时间格式化器
    ///
    /// 此格式化器配置为：
    /// - 使用缩写样式（如："2小时前"）
    /// - 更紧凑的显示格式
    ///
    /// # 示例
    /// ```swift
    /// let pastDate = Date().addingTimeInterval(-1800) // 30分钟前
    /// let formatted = RelativeDateTimeFormatter.short.localizedString(for: pastDate, relativeTo: Date())
    /// print(formatted) // 输出简短格式
    /// ```
    nonisolated(unsafe) static let short: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .numeric
        return formatter
    }()
}
