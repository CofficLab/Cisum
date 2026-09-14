import Foundation

/// 音频错误文案的本地化辅助函数。
///
/// 所有音频错误类型的 `errorDescription` / `failureReason` / `recoverySuggestion`
/// 都通过该函数读取本地化字符串，保证文案统一走本包的 `Localizable.xcstrings`。
///
/// 必须传入 `bundle: .module`：插件是独立 SPM Package，缺失时会 fallback 到主 App bundle，
/// 运行时找不到翻译资源而直接返回 key。
func audioErrorString(_ keyAndValue: String.LocalizationValue) -> String {
    String(localized: keyAndValue, bundle: .module)
}
