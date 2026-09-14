import Foundation

/// 音频错误文案的本地化辅助函数。
///
/// 所有音频错误类型的 `errorDescription` / `failureReason` / `recoverySuggestion`
/// 都通过该函数读取本地化字符串，保证文案统一走 `Localizable.xcstrings`。
func audioErrorString(_ keyAndValue: String.LocalizationValue) -> String {
    String(localized: keyAndValue)
}
