import Foundation
import MagicKit

/// 音频自动下载的纯判定策略（迁移 Phase 5）。
///
/// ViewModel 内联的下载判定被提取到这里，使场景激活、去重、
/// 代际与文件身份规则可以脱离 SwiftUI/Provider 独立测试。
enum AudioDownloadRequestPolicy {
    /// 是否应检查当前资产（音乐场景且存在资产）。
    static func shouldCheckCurrentAsset(isSceneActive: Bool, asset: URL?) -> Bool {
        isSceneActive && asset != nil
    }

    /// 是否应发起下载（场景激活、资产存在且未下载）。
    static func shouldStartDownload(isSceneActive: Bool, asset: URL?, isNotDownloaded: Bool) -> Bool {
        guard shouldCheckCurrentAsset(isSceneActive: isSceneActive, asset: asset) else { return false }
        return isNotDownloaded
    }

    /// 是否应发起下载（额外排除文件身份与进行中下载重复的资产）。
    static func shouldStartDownload(
        isSceneActive: Bool,
        asset: URL?,
        isNotDownloaded: Bool,
        activeDownloads: [URL]
    ) -> Bool {
        guard shouldStartDownload(isSceneActive: isSceneActive, asset: asset, isNotDownloaded: isNotDownloaded) else {
            return false
        }
        guard let asset else { return false }
        return !activeDownloads.contains { $0.isSameFileLocation(as: asset) }
    }

    /// 下载结果是否仍对应当前资产（按文件身份）。
    static func shouldApplyDownloadResult(requestedAsset: URL?, currentAsset: URL?) -> Bool {
        guard let requestedAsset, let currentAsset else { return false }
        return requestedAsset.isSameFileLocation(as: currentAsset)
    }

    /// 场景激活下的结果应用判定。
    static func shouldApplyDownloadResult(
        requestedAsset: URL?,
        currentAsset: URL?,
        isSceneActive: Bool
    ) -> Bool {
        isSceneActive && shouldApplyDownloadResult(requestedAsset: requestedAsset, currentAsset: currentAsset)
    }

    /// 场景激活且代际一致下的结果应用判定。
    static func shouldApplyDownloadResult(
        requestedAsset: URL?,
        currentAsset: URL?,
        isSceneActive: Bool,
        currentGeneration: Int,
        requestGeneration: Int
    ) -> Bool {
        currentGeneration == requestGeneration
            && shouldApplyDownloadResult(
                requestedAsset: requestedAsset,
                currentAsset: currentAsset,
                isSceneActive: isSceneActive
            )
    }

    /// 场景切走后的代际推进。
    static func generationAfterDeactivation(_ generation: Int) -> Int {
        generation + 1
    }
}
