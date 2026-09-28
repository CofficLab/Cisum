import Combine
import ProviderPlugin
import SwiftUI

@MainActor
final class CisumRootLayoutViewModel: ObservableObject {
    private let pluginProvider: (any PluginProviding)?
    private var pluginHandle: (any PluginProvidingObserverHandle)?
    @Published private(set) var contributionRevision = 0

    init(pluginProvider: (any PluginProviding)?) {
        self.pluginProvider = pluginProvider
    }

    var toolbarButtons: [(id: String, view: AnyView)] {
        _ = contributionRevision
        return pluginProvider?.getToolBarButtons() ?? []
    }

    var statusViews: [AnyView] {
        _ = contributionRevision
        return pluginProvider?.getStatusViews() ?? []
    }

    func start() {
        guard pluginHandle == nil else { return }
        pluginHandle = pluginProvider?.addObserver { [weak self] event in
            guard case .contributionsChanged = event else { return }
            self?.contributionRevision &+= 1
        }
    }

    func cancel() {
        pluginHandle?.cancel()
        pluginHandle = nil
    }
}
