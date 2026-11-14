import Foundation

/// 提供常用调度队列和线程相关工具的便捷访问协议
///
/// `SuperThread` 协议为 GCD（Grand Central Dispatch）队列提供了简化的接口，
/// 并提供了线程管理相关的辅助属性。
///
/// ## 使用示例:
/// ```swift
/// class MyClass: SuperThread {
///     func processData() {
///         // 在后台队列执行
///         bg.async {
///             // 执行耗时计算
///             let result = heavyComputation()
///             
///             // 在主队列更新UI
///             main.async {
///                 updateUI(with: result)
///             }
///         }
///         
///         // 创建自定义队列
///         let customQueue = makeQueue(name: "com.myapp.customQueue")
///         customQueue.async {
///             // 在自定义队列中执行工作
///         }
///     }
/// }
/// ```
public protocol SuperThread {
    
}

extension SuperThread {
    /// 获取主队列
    /// - Returns: 主线程的 DispatchQueue
    public var main: DispatchQueue {
        .main
    }
    
    /// 获取全局后台队列（简写）
    /// - Returns: 全局并发队列
    public var bg: DispatchQueue {
        .global()
    }
    
    /// 获取后台优先级的全局队列
    /// - Returns: 后台优先级的 DispatchQueue
    public var background: DispatchQueue {
        .global(qos: .background)
    }
    
    /// 获取默认文件管理器实例
    /// - Returns: FileManager 的默认实例
    public var f: FileManager {
        FileManager.default
    }
    
    /// 创建一个新的串行调度队列
    /// - Parameter name: 队列的唯一标识符名称
    /// - Returns: 新创建的后台优先级串行队列
    public func makeQueue(name: String) -> DispatchQueue {
        DispatchQueue(label: name, qos: .background)
    }
}

extension SuperThread {
    /// 获取当前线程的名称标识
    /// - Returns: 如果是主线程返回 "[🔥]"，否则返回空字符串
    public var threadName: String {
        "\(Thread.isMainThread ? "[🔥]" : "")"
    }
}
