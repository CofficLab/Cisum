import Combine
import CisumKernel

@MainActor
final class SettingsWindowViewModel: ObservableObject {
    @Published private(set) var navigationItems: [PluginSettingNavigationItem] = []

    private weak var settings: (any PluginProviding)?
    private var observer: PluginProvidingObserver?

    init(settings: (any PluginProviding)?) {
        attach(to: settings)
    }

    func attach(to settings: (any PluginProviding)?) {
        observer?.cancel()
        observer = nil
        self.settings = settings
        refresh()

        guard let settings else { return }
        observer = PluginProvidingObserver(provider: settings, viewModel: self)
    }

    func handle(_ event: PluginProvidingEvent) {
        switch event {
        case .pluginsChanged, .contributionsChanged:
            refresh()
        }
    }

    private func refresh() {
        navigationItems = settings?.getSettingNavigationItems() ?? []
    }
}

@MainActor
private final class PluginProvidingObserver {
    private weak var viewModel: SettingsWindowViewModel?
    private var handle: (any PluginProvidingObserverHandle)?

    init(provider: any PluginProviding, viewModel: SettingsWindowViewModel) {
        self.viewModel = viewModel
        handle = provider.addObserver { [weak self] event in
            self?.viewModel?.handle(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
