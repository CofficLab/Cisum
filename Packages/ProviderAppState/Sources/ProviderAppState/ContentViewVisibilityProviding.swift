import Foundation

/// 内容区（音乐库）显隐的服务契约。
///
/// ## 为什么需要这个契约
///
/// 历史上显隐有两个互不相通的真源：
/// - `AppStateProviding.isDBViewVisible`：落盘 `UserDefaults`，是**用户显式选择**的持久化态；
/// - `RootViewProviding.isContentViewHidden`：纯内存，根布局直接消费。
///
/// 两者之间只有启动时一条单向通路（把落盘值灌进根视图），反向没有任何订阅：
/// - 播放控制区的「更多」按钮过去直接改根视图的内存态，**不落盘**，
///   于是「收起」这个动作重启后就丢了；
/// - `AppStateProviding` 侧发出的 `.dbViewVisibilityChanged` 事件全仓库没有任何
///   生产代码订阅，于是「打开音乐库」这类入口点了没反应；
/// - 两套状态一旦分叉（「更多」按钮按落盘值取反，而落盘值可能已被旧缺陷写坏），
///   用户就会看到一个**点不动的按钮**，以及一个**每次冷启动都只剩空播放器**的界面。
///
/// 本契约把显隐收敛成**一个可解析的服务**：插件只管调用，
/// 落盘、投影与分歧处理由实现方（`FactoryCisum` 组装的协调器）统一负责。
/// 契约放在 `Provider*` 包里，插件只依赖契约、不依赖对方的实现包。
@MainActor
public protocol ContentViewVisibilityProviding: AnyObject {
    /// 内容区当前是否可见（以用户实际看到的状态为准）。
    var isContentViewVisible: Bool { get }

    /// 显式设置内容区显隐：落盘并立即生效。
    func setContentViewVisible(_ visible: Bool)

    /// 显式切换内容区显隐。
    ///
    /// 目标态以**当前实际可见性**取反，而不是落盘值：桌面端「窗口太矮自动收起
    /// 副栏」只改内存态，若按落盘值取反，用户在矮窗口下点「更多」会得到
    /// 「点了没反应」。
    func toggleContentView()
}
