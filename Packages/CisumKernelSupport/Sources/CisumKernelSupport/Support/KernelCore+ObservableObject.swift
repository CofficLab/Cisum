import Foundation
import KernelCore
import Combine

/// 让共享内核容器可被 SwiftUI `@ObservedObject` 持有。
///
/// LumiKernel 的 `KernelCoreContainer` 不遵循 `ObservableObject`；Cisum 宿主
/// 视图沿用 `@ObservedObject var kernel` 的写法。空 conformance 采用协议默认
/// 实现（不监听任何 `@Published`），实际 UI 刷新仍由 `.cisumEnabledPluginsDidChange`
/// 等 NotificationCenter 通知驱动（`contributionRevision` 机制），与旧门面包
/// 的 objectWillChange 转发语义等价。
extension KernelCoreContainer: ObservableObject {}
