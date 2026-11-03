import Foundation

/// iCloud 键值库（`NSUbiquitousKeyValueStore`）的窄契约。
///
/// ## 为什么抽出这一层
///
/// `NSUbiquitousKeyValueStore.default` 有两个对测试极不友好的性质：
///
/// 1. **进程级全局单例** —— 单元测试无法替换，写入即污染进程内其它用例；
/// 2. **可用性取决于设备是否登录 iCloud** —— 未登录或容器不可用时，
///    `set` / `string` 的行为与已登录设备不同。同一份断言在不同开发者的
///    机器上会得到不同结论，这是「跨机结果不一致」的主要来源之一。
///
/// 抽出协议后，生产行为完全不变（默认实现仍转发到 `.default`），
/// 而单元测试可以注入 ``InMemoryCloudKeyValueStore``，把 iCloud 通道
/// 变成确定性的内存状态。
///
/// - Note: 本协议只覆盖**字符串通道**。当前所有需要 iCloud 同步的值
///   （书籍 URL、书籍时间、播放模式、播放 URL）都以字符串形态同步，
///   本地通道的类型化存取由 `UserDefaults` 自身负责。
public protocol CloudKeyValueStore: AnyObject, Sendable {
    /// 读取字符串值。
    func string(forKey key: String) -> String?

    /// 写入字符串值。`nil` 等价于移除。
    func set(_ value: String?, forKey key: String)

    /// 移除某个键。
    func removeObject(forKey key: String)

    /// 强制同步到服务端。
    func synchronize()
}

/// 生产实现：转发到 `NSUbiquitousKeyValueStore.default`。
public final class UbiquitousKeyValueStore: CloudKeyValueStore, @unchecked Sendable {
    /// 生产共享实例。
    public static let shared = UbiquitousKeyValueStore()

    private let store: NSUbiquitousKeyValueStore

    public init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    public func string(forKey key: String) -> String? {
        store.string(forKey: key)
    }

    public func set(_ value: String?, forKey key: String) {
        store.set(value, forKey: key)
    }

    public func removeObject(forKey key: String) {
        store.removeObject(forKey: key)
    }

    public func synchronize() {
        store.synchronize()
    }
}

/// 测试实现：纯内存，行为与 `NSUbiquitousKeyValueStore` 的字符串通道一致。
///
/// 与真实实现的关键差异（都是**期望中的**差异）：
/// - 不依赖 iCloud 账号，**任何机器上行为完全相同**；
/// - 不与其它测试共享状态，每个用例持有自己的实例。
public final class InMemoryCloudKeyValueStore: CloudKeyValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String]

    /// - Parameter initialValues: 初始内容。用于模拟「值只存在于 iCloud、
    ///   本地没有」这类回退路径。
    public init(initialValues: [String: String] = [:]) {
        self.storage = initialValues
    }

    public func string(forKey key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    public func set(_ value: String?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    public func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    public func synchronize() {
        // 内存实现无需同步。
    }

    /// 当前全部内容。用于断言「写入了哪些键」。
    public var allValues: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
