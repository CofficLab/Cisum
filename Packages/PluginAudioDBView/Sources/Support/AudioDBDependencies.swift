import ProviderAudioLibrary
import SwiftUI

public struct AudioDBDependencies: @unchecked Sendable {
    /// 音频库能力（Capabilities 目录收窄），内部惰性解析内核 Provider。
    public var library: any AudioLibraryCapability
    public var audioDisk: @MainActor @Sendable () -> URL?
    public var audioDiagnostics: @MainActor @Sendable () -> AudioStorageDiagnostics
    public var supportedExtensions: [String]
    public var isDesktop: Bool
    public var isNotDesktop: Bool
    public var showDBView: @MainActor @Sendable () -> Void
    public var isImporting: Binding<Bool>

    public init(
        library: any AudioLibraryCapability,
        audioDisk: @escaping @MainActor @Sendable () -> URL?,
        audioDiagnostics: @escaping @MainActor @Sendable () -> AudioStorageDiagnostics,
        supportedExtensions: [String],
        isDesktop: Bool,
        isNotDesktop: Bool,
        showDBView: @escaping @MainActor @Sendable () -> Void,
        isImporting: Binding<Bool>
    ) {
        self.library = library
        self.audioDisk = audioDisk
        self.audioDiagnostics = audioDiagnostics
        self.supportedExtensions = supportedExtensions
        self.isDesktop = isDesktop
        self.isNotDesktop = isNotDesktop
        self.showDBView = showDBView
        self.isImporting = isImporting
    }

    /// 空依赖：音频库能力解析为 `nil`（Provider 未就绪 / 数据层插件缺席）。
    ///
    /// 标记 `@MainActor`：`AudioLibraryCapabilityAdapter` 的构造是 MainActor 隔离的。
    @MainActor
    public static let empty = AudioDBDependencies(
        library: AudioLibraryCapabilityAdapter(resolve: { nil }),
        audioDisk: { nil },
        audioDiagnostics: { AudioStorageDiagnosticsFactory.make(storage: nil) },
        supportedExtensions: [],
        isDesktop: true,
        isNotDesktop: false,
        showDBView: {},
        isImporting: .constant(false)
    )
}