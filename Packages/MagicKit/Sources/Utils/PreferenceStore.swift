import Foundation

/// 本地偏好 + iCloud 键值库的**双通道**偏好存储。
///
/// ## 为什么需要这一层
///
/// Cisum 有多处状态同时写入两个通道：本地 `UserDefaults` 与 iCloud
/// `NSUbiquitousKeyValueStore`。两者的读取语义是「本地优先，iCloud 兜底」。
///
/// 过去这段逻辑以 `static` 方法 + `.standard` / `.default` 硬编码实现，
/// 带来两个问题：
///
/// 1. **无法在单元测试中替换** —— 只能靠「纯函数旁路」覆盖分支，
///    真实的读写路径从未被 hermetic 地测到；
/// 2. **污染开发者真实环境** —— 测试写入的是开发者真实的偏好与
///    **真实的 iCloud 键值库**，后者是否可读写取决于设备是否登录 iCloud。
///
/// 抽出本类型后：
/// - 生产路径行为完全不变（默认参数就是 `.standard` + 真实 iCloud）；
/// - 单元测试注入 `UserDefaults(suiteName:)` 与 ``InMemoryCloudKeyValueStore``，
///   得到**与开发者设备状态无关**的确定性行为。
public final class PreferenceStore: @unchecked Sendable {
    /// 本地偏好。
    public let defaults: UserDefaults

    /// iCloud 键值库。
    public let cloud: CloudKeyValueStore

    /// - Parameters:
    ///   - defaults: 本地偏好存储。生产传 `.standard`。
    ///   - cloud: iCloud 键值库。生产传 ``UbiquitousKeyValueStore/shared``。
    public init(
        defaults: UserDefaults = .standard,
        cloud: CloudKeyValueStore = UbiquitousKeyValueStore.shared
    ) {
        self.defaults = defaults
        self.cloud = cloud
    }

    /// 生产共享实例：使用真实 `UserDefaults.standard` 与真实 iCloud 键值库。
    public static let shared = PreferenceStore()

    // MARK: - 字符串通道

    /// 读取字符串：本地优先，iCloud 兜底。
    public func string(forKey key: String) -> String? {
        if let local = defaults.string(forKey: key) {
            return local
        }
        return cloud.string(forKey: key)
    }

    /// 写入字符串到两个通道。
    public func set(_ value: String?, forKey key: String) {
        defaults.set(value, forKey: key)
        cloud.set(value, forKey: key)
        cloud.synchronize()
    }

    /// 移除两个通道中的键。
    public func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
        cloud.removeObject(forKey: key)
        cloud.synchronize()
    }

    // MARK: - URL 通道

    /// 读取 URL：本地优先，iCloud 兜底；命中 iCloud 时回填本地。
    ///
    /// - Parameter parser: 从 iCloud 字符串解析 URL 的策略。
    public func url(forKey key: String, parser: (String) -> URL?) -> URL? {
        if let url = defaults.url(forKey: key) {
            return url
        }
        guard let url = parser(cloud.string(forKey: key) ?? "") else { return nil }
        // 从 iCloud 读到后回填本地，后续读取不再依赖 iCloud 可用性。
        defaults.set(url, forKey: key)
        return url
    }

    // MARK: - 时间通道

    /// 读取时间：本地优先，iCloud 兜底；命中 iCloud 时回填本地。
    ///
    /// - Parameters:
    ///   - key: 存储键。
    ///   - isValid: 判定本地数值是否有效的谓词。
    public func time(forKey key: String, isValid: (TimeInterval) -> Bool) -> TimeInterval? {
        let localObject = defaults.object(forKey: key)
        let localDouble = defaults.double(forKey: key)
        if localObject != nil, isValid(localDouble) {
            return localDouble
        }
        guard let raw = cloud.string(forKey: key),
              let value = TimeInterval(raw),
              isValid(value) else { return nil }
        defaults.set(value, forKey: key)
        return value
    }
}
