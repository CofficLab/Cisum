import Foundation
import ProviderAudioNavigation

/// ControlButtons 所需的曲目导航能力适配器，由插件入口解析 Kernel Provider 后组装。
@MainActor
final class NavigationCapabilityAdapter: NavigationCapability {
    private let navigation: any AudioTrackNavigationProviding

    init(navigation: any AudioTrackNavigationProviding) {
        self.navigation = navigation
    }

    func nextURL(after current: URL?) async throws -> URL? {
        try await navigation.nextURL(after: current, verbose: true)
    }

    func previousURL(before current: URL?) async throws -> URL? {
        try await navigation.previousURL(before: current, verbose: true)
    }

    func firstURL() async throws -> URL? {
        try await navigation.firstURL()
    }

    func lastURL() async throws -> URL? {
        try await navigation.lastURL()
    }
}
