import OSLog
import WidgetKit

/// 小组件时间线索引
struct SimpleEntry: TimelineEntry {
    /// 日期
    let date: Date
    /// 小组件数据
    let data: WidgetData

    /// 占位符条目（用于预览）
    static var placeholder: SimpleEntry {
        SimpleEntry(
            date: Date(),
            data: .empty
        )
    }
}

/// 小组件时间线提供者
/// 负责生成和更新小组件显示的内容
struct Provider: TimelineProvider {
    private let logger = Logger(subsystem: "com.yueyi.cisum.widget", category: "Provider")

    /// 提供占位符内容
    /// - Parameter context: 上下文
    /// - Returns: 占位符条目
    func placeholder(in context: Context) -> SimpleEntry {
        return SimpleEntry.placeholder
    }

    /// 提供快照内容（用于预览）
    /// - Parameters:
    ///   - context: 上下文
    ///   - completion: 完成回调
    func getSnapshot(in context: Context, completion: @escaping @Sendable (SimpleEntry) -> Void) {
        let data = WidgetData.load()
        let entry = SimpleEntry(date: Date(), data: data)
        completion(entry)
    }

    /// 获取时间线
    /// - Parameters:
    ///   - context: 上下文
    ///   - completion: 完成回调
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SimpleEntry>) -> Void) {
        let data = WidgetData.load()
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, data: data)
        
        // 如果正在播放，更新频率高一点？其实我们主要靠 reloadAllTimelines 来驱动更新
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}
