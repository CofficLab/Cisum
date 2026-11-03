import Foundation

/// 通用设置页的唯一数据来源。
///
/// View 只读取本 ViewModel，不直接接触 Provider。
@MainActor
final class GeneralSettingsViewModel: ObservableObject {
    init() {}
}
