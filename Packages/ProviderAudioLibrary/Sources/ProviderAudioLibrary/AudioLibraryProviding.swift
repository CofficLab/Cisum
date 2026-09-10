import Foundation

@MainActor
public enum AudioLibraryProvidingEvent {
    case libraryChanged(totalCount: Int)
}

@MainActor
public protocol AudioLibraryProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 音频库能力协议。
///
/// Kernel 只定义 AudioDB 所需的抽象能力，不依赖 `AudioRepo` 或任何具体
/// 音频插件模块。具体的音频插件可以在 `onBoot` 阶段注册实现。
@MainActor
public protocol AudioLibraryProviding: AnyObject, ObservableObject {
    /// 音频仓库；由数据层插件构造并提供给视图层消费。
    var audioRepo: AudioRepo? { get async }

    /// 当前音频文件所在的目录。
    var audioDisk: URL? { get }

    /// 当前实现支持导入的文件扩展名。
    var supportedExtensions: [String] { get }

    /// 音频库是否已准备好访问。
    var isAvailable: Bool { get }

    /// 当前音频库中的项目数量。
    func totalCount() async -> Int

    @discardableResult
    func addObserver(_ callback: @escaping (AudioLibraryProvidingEvent) -> Void) -> any AudioLibraryProvidingObserverHandle
}

public extension AudioLibraryProviding {
    @discardableResult
    func addObserver(_ callback: @escaping (AudioLibraryProvidingEvent) -> Void) -> any AudioLibraryProvidingObserverHandle {
        NoopAudioLibraryProvidingObserverHandle()
    }
}

@MainActor
public final class NoopAudioLibraryProvidingObserverHandle: AudioLibraryProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
