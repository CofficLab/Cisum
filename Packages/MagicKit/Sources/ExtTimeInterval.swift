import Foundation

/// TimeInterval 类型的扩展，提供时间格式化功能
public extension TimeInterval {
    /// 将时间间隔转换为播放器显示格式
    ///
    /// 根据时间长度自动选择显示格式：
    /// - 小于1小时：显示为 "mm:ss" 格式
    /// - 大于等于1小时：显示为 "hh:mm:ss" 格式
    ///
    /// ```swift
    /// let duration: TimeInterval = 3665 // 1小时1分5秒
    /// print(duration.displayFormat) // "1:01:05"
    ///
    /// let shortDuration: TimeInterval = 125 // 2分5秒
    /// print(shortDuration.displayFormat) // "2:05"
    /// ```
    /// - Returns: 格式化后的时间字符串，格式为 "mm:ss" 或 "hh:mm:ss"
    var displayFormat: String {
        TimeFormatter.format(self)
    }
}

/// 时间格式化工具结构体
public struct TimeFormatter {
    private static let maximumDisplaySeconds = Int.max / 2

    /// 将时间间隔转换为显示格式
    ///
    /// 根据时间长度自动选择显示格式：
    /// - 小于1小时：显示为 "mm:ss" 格式
    /// - 大于等于1小时：显示为 "hh:mm:ss" 格式
    ///
    /// ```swift
    /// let duration: TimeInterval = 3665
    /// print(TimeFormatter.format(duration)) // "1:01:05"
    /// ```
    /// - Parameter timeInterval: 时间间隔（秒）
    /// - Returns: 格式化后的时间字符串，格式为 "mm:ss" 或 "hh:mm:ss"
    public static func format(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = normalizedSeconds(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    static func normalizedSeconds(_ timeInterval: TimeInterval) -> Int {
        guard timeInterval.isFinite, timeInterval > 0 else { return 0 }
        return Int(min(timeInterval, TimeInterval(maximumDisplaySeconds)))
    }
}
