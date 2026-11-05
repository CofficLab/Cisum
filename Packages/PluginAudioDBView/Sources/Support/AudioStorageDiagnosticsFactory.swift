import CisumProviderStorage
import Foundation
import MagicKit
import ProviderAudioLibrary

@MainActor
enum AudioStorageDiagnosticsFactory {
    /// 由存储 Provider 生成「仓库路径解析诊断」，供错误视图展示。
    ///
    /// 保留 `any StorageProviding` 而不收窄为能力：此处是**纯诊断快照**，
    /// 只在错误视图打开时调用一次、不持有 Provider（参数非存储属性），
    /// 且 `StorageProviding` 是 Lumi 共享契约、并非本插件消费的核心能力。
    /// 按 Capabilities 规范的「不必建」判据：不订阅、不重试、生命周期不重叠。
    /// - Parameters:
    ///   - storage: 存储 Provider（可能为 nil）。
    ///
    /// - Note: 存储位置的原始值直接取自 Provider。配置已改为落盘
    ///   （`<dataRoot>/<pluginID>/storage-location.json`），不再经过偏好域——
    ///   这里若继续读 `UserDefaults` 会永远拿到 nil，诊断面板会误报
    ///   「未设置存储位置」。
    static func make(
        storage: (any StorageProviding)?
    ) -> AudioStorageDiagnostics {
        let storageLocationRaw = storage?.currentStorageLocation?.rawValue
        let isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        let cloudContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil)
        let cloudDocuments = cloudContainer?.appendingPathComponent("Documents")
        let localDocuments = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storageRoot = storage?.storageRoot
        let disk = storageRoot?.appendingPathComponent(
            AudioPluginInfo.effectiveDBDirName,
            isDirectory: true
        )

        return AudioStorageDiagnostics(
            storageLocationRaw: storageLocationRaw,
            isICloudAvailable: isICloudAvailable,
            hasUsableStorageLocation: storage?.hasUsableStorageLocation ?? false,
            cloudContainer: cloudContainer?.path,
            cloudDocuments: cloudDocuments?.path,
            localDocuments: localDocuments?.path,
            storageRoot: storageRoot?.path,
            audioDisk: disk?.path,
            dbDirName: AudioPluginInfo.effectiveDBDirName
        )
    }
}