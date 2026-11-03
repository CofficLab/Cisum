import Foundation

/// 确定性的「等待某条件成立」工具。
///
/// ## 为什么需要它
///
/// 单元测试里等待异步状态收敛，常见写法是：
///
/// ```swift
/// for _ in 0..<100 where await library.totalCount() != 2 {
///     try await Task.sleep(nanoseconds: 20_000_000)
/// }
/// ```
///
/// 这个写法有三个问题：
///
/// 1. **预算与机器速度耦合** —— 100 × 20ms = 2s 预算，慢机器（CI、
///    负载高的开发机）可能不够，快机器则白等 2s；
/// 2. **失败信息缺失** —— 循环耗尽后没有说明「等了多久、期望什么、
///    实际是什么」，只能看到一句 `Expectation failed`；
/// 3. **`where` 条件在每轮循环前求值** —— 条件翻转即退出循环，语义正确
///    但极易被误改成「循环固定次数」。
///
/// 本工具把「等多久」「等什么」「失败时说什么」三件事显式化：
///
/// - **按墙钟时间给预算**（而非固定轮数），与机器速度解耦；
/// - **失败时给出可诊断的信息**；
/// - **轮询间隔可注入**，测试可以调小以加速。
///
/// ## 与生产代码的边界
///
/// 本类型只被测试使用，但放在 `MagicKit` 里是因为它需要被多个包共享
/// （各包的 `Tests/` 无法互相依赖）。它不引用任何测试框架，
/// 因此不会把 `Testing` 带进生产二进制。
public enum DeterministicWait {
    /// 默认等待预算（秒）。
    public static let defaultTimeout: TimeInterval = 5

    /// 默认轮询间隔（秒）。
    public static let defaultPollInterval: TimeInterval = 0.01

    /// 在 **MainActor** 上等待条件成立。
    ///
    /// 绝大多数 UI 相关的单元测试的被测对象都是 `@MainActor` 隔离的
    /// （ViewModel、Provider），条件闭包必须能访问它们的隔离状态，
    /// 因此这里提供 MainActor 版本——闭包在 MainActor 上求值，
    /// 访问 `@MainActor` 属性合法。
    ///
    /// - Parameters:
    ///   - description: 条件的描述，用于失败信息。
    ///   - timeout: 等待预算（秒）。超时后返回 `false`。
    ///   - pollInterval: 轮询间隔（秒）。
    ///   - condition: 条件。返回 `true` 表示已成立。
    /// - Returns: 条件在预算内成立则返回 `true`，否则返回 `false`。
    @discardableResult
    @MainActor
    public static func until(
        _ description: String,
        timeout: TimeInterval = defaultTimeout,
        pollInterval: TimeInterval = defaultPollInterval,
        _ condition: () async -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        // 最后再试一次：条件可能恰好在预算耗尽的瞬间成立。
        return await condition()
    }

    /// 在 **MainActor** 上等待条件成立并在超时时报告失败。
    ///
    /// - Parameters:
    ///   - description: 条件的描述，同时作为失败信息。
    ///   - timeout: 等待预算（秒）。
    ///   - pollInterval: 轮询间隔（秒）。
    ///   - onTimeout: 超时回调。测试里通常传 `{ Issue.record($0) }`。
    ///   - condition: 条件。
    /// - Returns: 条件是否在预算内成立。
    @discardableResult
    @MainActor
    public static func expect(
        _ description: String,
        timeout: TimeInterval = defaultTimeout,
        pollInterval: TimeInterval = defaultPollInterval,
        onTimeout: (String) -> Void = { _ in },
        _ condition: () async -> Bool
    ) async -> Bool {
        let satisfied = await until(
            description,
            timeout: timeout,
            pollInterval: pollInterval,
            condition
        )
        if !satisfied {
            onTimeout("等待超时（\(Int(timeout))s）：\(description)")
        }
        return satisfied
    }
}
