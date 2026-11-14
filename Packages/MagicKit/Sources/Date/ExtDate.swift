import Foundation

/// Date 类型的扩展，提供常用的日期格式化和转换功能
public extension Date {
    /// 获取当前时间的标准格式字符串
    ///
    /// 返回格式为 "yyyy-MM-dd HH:mm:ss" 的当前时间字符串，使用系统当前时区
    ///
    /// # 示例
    /// ```swift
    /// let currentTime = Date.now
    /// print(currentTime) // 输出类似: "2024-03-15 14:30:45"
    /// ```
    static var now: String {
        Date().fullDateTime
    }
    
    /// 获取当前时间的紧凑格式字符串
    ///
    /// 返回格式为 "yyyyMMddHHmmss" 的当前时间字符串，使用系统当前时区
    ///
    /// # 示例
    /// ```swift
    /// let compactTime = Date.nowCompact
    /// print(compactTime) // 输出类似: "20240315143045"
    /// ```
    static var nowCompact: String {
        Date().compactDateTime
    }
    
    // MARK: - 实例属性
    
    /// 完整的日期时间字符串
    ///
    /// 将日期转换为 "yyyy-MM-dd HH:mm:ss" 格式的字符串，使用系统当前时区
    ///
    /// # 示例
    /// ```swift
    /// let date = Date()
    /// print(date.fullDateTime) // 输出类似: "2024-03-15 14:30:45"
    /// ```
    var fullDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
    
    /// 紧凑的日期时间字符串
    ///
    /// 将日期转换为 "yyyyMMddHHmmss" 格式的字符串，使用系统当前时区
    ///
    /// # 示例
    /// ```swift
    /// let date = Date()
    /// print(date.compactDateTime) // 输出类似: "20240315143045"
    /// ```
    var compactDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
    
    /// 日志时间字符串
    ///
    /// 将日期转换为 "HH:mm:ss" 格式的字符串，适用于日志记录
    ///
    /// # 示例
    /// ```swift
    /// let date = Date()
    /// print(date.logTime) // 输出类似: "14:30:45"
    /// ```
    var logTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: self)
    }
    
    // MARK: - 静态工具方法
    
    /// 将可选日期转换为字符串
    ///
    /// - Parameter date: 需要转换的可选日期
    /// - Returns: 如果日期存在，返回格式化的日期字符串；如果为 nil，返回 "-"
    ///
    /// # 示例
    /// ```swift
    /// let date: Date? = Date()
    /// print(Date.toString(date)) // 输出类似: "2024-03-15 14:30:45"
    ///
    /// let nilDate: Date? = nil
    /// print(Date.toString(nilDate)) // 输出: "-"
    /// ```
    static func toString(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        return date.fullDateTime
    }
    
    /// 相对时间字符串
    ///
    /// 将日期转换为相对于当前时间的描述，如"just now"、"5 minutes ago"、"2 hours ago"、"3 days ago"等
    ///
    /// # 示例
    /// ```swift
    /// let fiveMinutesAgo = Date().addingTimeInterval(-300)
    /// print(fiveMinutesAgo.relativeTime) // 输出: "5 minutes ago"
    /// 
    /// let twoHoursAgo = Date().addingTimeInterval(-7200)
    /// print(twoHoursAgo.relativeTime) // 输出: "2 hours ago"
    /// ```
    var relativeTime: String {
        DateRelativeTimePolicy.relativeTime(for: self)
    }
    
    /// 智能相对时间字符串
    ///
    /// 根据时间间隔智能选择最合适的显示格式：
    /// - 1分钟内：显示"just now"
    /// - 1小时内：显示分钟
    /// - 1天内：显示小时
    /// - 7天内：显示天数
    /// - 超过7天：显示具体日期
    ///
    /// # 示例
    /// ```swift
    /// let date = Date().addingTimeInterval(-86400 * 10) // 10天前
    /// print(date.smartRelativeTime) // 输出具体日期格式
    /// ```
    var smartRelativeTime: String {
        DateRelativeTimePolicy.smartRelativeTime(for: self)
    }
}

enum DateRelativeTimePolicy {
    private static let maximumDisplayUnit = Int.max / 2

    static func relativeTime(for date: Date, now: Date = Date()) -> String {
        let timeInterval = now.timeIntervalSince(date)
        guard timeInterval.isFinite else { return "just now" }

        // 如果是未来时间
        if timeInterval < 0 {
            let futureInterval = -timeInterval
            if futureInterval < 60 {
                return "soon"
            } else if futureInterval < 3600 {
                let minutes = boundedInt(futureInterval / 60)
                return "\(minutes) \(unit("minute", count: minutes)) from now"
            } else if futureInterval < 86400 {
                let hours = boundedInt(futureInterval / 3600)
                return "\(hours) \(unit("hour", count: hours)) from now"
            } else {
                let days = boundedInt(futureInterval / 86400)
                return "\(days) \(unit("day", count: days)) from now"
            }
        }

        // 过去时间
        if timeInterval < 60 {
            return "just now"
        } else if timeInterval < 3600 {
            let minutes = boundedInt(timeInterval / 60)
            return "\(minutes) \(unit("minute", count: minutes)) ago"
        } else if timeInterval < 86400 {
            let hours = boundedInt(timeInterval / 3600)
            return "\(hours) \(unit("hour", count: hours)) ago"
        } else if timeInterval < 604800 {
            let days = boundedInt(timeInterval / 86400)
            return "\(days) \(unit("day", count: days)) ago"
        } else if timeInterval < 2592000 {
            let weeks = boundedInt(timeInterval / 604800)
            return "\(weeks) \(unit("week", count: weeks)) ago"
        } else if timeInterval < 31536000 {
            let months = boundedInt(timeInterval / 2592000)
            return "\(months) \(unit("month", count: months)) ago"
        } else {
            let years = boundedInt(timeInterval / 31536000)
            return "\(years) \(unit("year", count: years)) ago"
        }
    }

    static func smartRelativeTime(for date: Date, now: Date = Date()) -> String {
        let timeInterval = now.timeIntervalSince(date)
        guard timeInterval.isFinite else { return "just now" }

        if timeInterval < 604800 { // 7天内使用相对时间
            return relativeTime(for: date, now: now)
        } else { // 超过7天显示具体日期
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }

    private static func boundedInt(_ value: TimeInterval) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        return Int(min(value, TimeInterval(maximumDisplayUnit)))
    }

    private static func unit(_ singular: String, count: Int) -> String {
        count == 1 ? singular : "\(singular)s"
    }
}
