import CoreGraphics
import Foundation
import ProviderAppState
import ProviderAudioLibrary
import SwiftUI
import Testing
@testable import PluginAudioControlButtons

// MARK: - 探针

/// 内核 `AudioLibraryProviding` 的最小实现：用于验证仓库状态的翻译规则。
@MainActor
private final class AudioLibraryProviderStub: AudioLibraryProviding {
    var audioDisk: URL? = URL(fileURLWithPath: "/tmp/audio")
    var supportedExtensions: [String] = ["mp3"]
    var isAvailable: Bool = true
    var totalCountValue = 0
    /// 仓库是否确认为空——结论由数据层给出，能力只读它。
    var isRepositoryEmpty = false

    private var callbacks: [UUID: (AudioLibraryProvidingEvent) -> Void] = [:]

    func totalCount() async -> Int { totalCountValue }
    func allURLs(reason: String) async -> [URL] { [] }
    func urls(offset: Int, limit: Int, reason: String) async -> [URL] { [] }
    func contains(_ url: URL) async -> Bool { false }
    func delete(urls: [URL], verbose: Bool) async throws {}
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}
    func sort(url: URL?, reason: String) async {}
    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLibraryProvidingEvent) -> Void
    ) -> any AudioLibraryProvidingObserverHandle {
        let id = UUID()
        callbacks[id] = callback
        return StubLibraryHandle { [weak self] in
            self?.callbacks.removeValue(forKey: id)
        }
    }

    func emit(_ event: AudioLibraryProvidingEvent) {
        for callback in Array(callbacks.values) { callback(event) }
    }
}

@MainActor
private final class StubLibraryHandle: AudioLibraryProvidingObserverHandle {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() { onCancel() }
}

/// 内核 `AppStateProviding` 的最小实现：用于验证内容区显隐能力。
@MainActor
private final class AppStateProviderStub: AppStateProviding {
    var isDemoMode = false
    var isDBViewVisible = true
    var isImporting = false
    var isDropping = false
    var hasDragOperation = false
    var stateMessage = ""

    private var callbacks: [UUID: (AppStateProvidingEvent) -> Void] = [:]

    func enterDemoMode() { isDemoMode = true }
    func exitDemoMode() { isDemoMode = false }
    func showDBView() { setDBView(true) }
    func hideDBView() { setDBView(false) }
    func closeDBView() { hideDBView() }
    func toggleDBView() { setDBView(!isDBViewVisible) }

    func setDBView(_ visible: Bool) {
        guard isDBViewVisible != visible else { return }
        isDBViewVisible = visible
        for callback in Array(callbacks.values) {
            callback(.dbViewVisibilityChanged(visible))
        }
    }

    func setImporting(_ importing: Bool) { isImporting = importing }
    func setDragOperation(_ active: Bool) { isDropping = active }
    func appendStateMessage(_ message: String) { stateMessage = message }
    func clearStateMessages() { stateMessage = "" }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AppStateProvidingEvent) -> Void
    ) -> any AppStateProvidingObserverHandle {
        let id = UUID()
        callbacks[id] = callback
        return StubAppStateHandle { [weak self] in
            self?.callbacks.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class StubAppStateHandle: AppStateProvidingObserverHandle {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() { onCancel() }
}

// MARK: - 仓库状态能力

/// 仓库状态能力的翻译规则：
/// - 结论直接读数据层的 `isRepositoryEmpty`，能力不自己解释计数；
/// - 只有结论变化才广播。
@MainActor
struct RepositoryStateCapabilityTests {
    private func makeCapability(
        _ provider: AudioLibraryProviderStub
    ) -> RepositoryStateCapabilityAdapter {
        RepositoryStateCapabilityAdapter { provider }
    }

    @Test
    func providerVerdictDecidesEmptyOrFilled() {
        let provider = AudioLibraryProviderStub()
        let capability = makeCapability(provider)
        var events: [RepositoryStateEvent] = []
        let handle = capability.addObserver { events.append($0) }

        // 订阅瞬间先读一次结论：Provider 已经知道仓库是空的。
        provider.isRepositoryEmpty = true
        provider.emit(.repositoryEmpty)
        #expect(capability.isEmpty)
        #expect(events.count == 1)

        // 结论翻转：仓库恢复非空。
        provider.isRepositoryEmpty = false
        provider.emit(.updated(totalCount: 3))
        #expect(!capability.isEmpty)
        #expect(events.count == 2)

        handle.cancel()
    }

    @Test
    func verdictIsNotDerivedFromEventCounts() {
        let provider = AudioLibraryProviderStub()
        let capability = makeCapability(provider)
        var events: [RepositoryStateEvent] = []
        let handle = capability.addObserver { events.append($0) }

        // 计数为 0，但数据层尚未确认结论：能力不自己下判断。
        provider.isRepositoryEmpty = false
        provider.emit(.synced(totalCount: 0))
        #expect(!capability.isEmpty)
        #expect(events.isEmpty)

        handle.cancel()
    }

    @Test
    func unchangedVerdictDoesNotBroadcast() {
        let provider = AudioLibraryProviderStub()
        let capability = makeCapability(provider)
        var events: [RepositoryStateEvent] = []
        let handle = capability.addObserver { events.append($0) }

        provider.emit(.syncing)
        provider.emit(.sorting)
        provider.emit(.sortCompleted)
        provider.emit(.synced(totalCount: 3))

        #expect(events.isEmpty)
        #expect(!capability.isEmpty)
        handle.cancel()
    }

    @Test
    func repositoryAvailabilityChangeDropsStaleConclusion() {
        let provider = AudioLibraryProviderStub()
        provider.isRepositoryEmpty = true
        let capability = makeCapability(provider)
        let handle = capability.addObserver { _ in }

        provider.emit(.repositoryEmpty)
        #expect(capability.isEmpty)

        // 仓库位置变了：数据层作废旧结论，等下一次扫描给新结论。
        provider.isRepositoryEmpty = false
        provider.emit(.repositoryAvailabilityChanged)
        #expect(!capability.isEmpty)

        handle.cancel()
    }

    @Test
    func cancelledObserverStopsReceivingEvents() {
        let provider = AudioLibraryProviderStub()
        let capability = makeCapability(provider)
        var events: [RepositoryStateEvent] = []
        let handle = capability.addObserver { events.append($0) }

        provider.isRepositoryEmpty = true
        provider.emit(.repositoryEmpty)
        handle.cancel()
        provider.isRepositoryEmpty = false
        provider.emit(.updated(totalCount: 3))

        #expect(events.count == 1)
    }

    @Test
    func missingProviderDoesNotCrashTheCapability() {
        let capability = RepositoryStateCapabilityAdapter { nil }
        var events: [RepositoryStateEvent] = []
        let handle = capability.addObserver { events.append($0) }

        #expect(!capability.isEmpty)
        #expect(events.isEmpty)
        handle.cancel()
    }
}

// MARK: - 内容区显隐能力

/// 显隐结论必须跟着事件走：显隐广播发生在协调器写根视图之前，
/// 此刻回头读根视图只会拿到旧值。
@MainActor
struct ContentVisibilityCapabilityTests {
    @Test
    func eventPayloadDrivesVisibility() {
        let appState = AppStateProviderStub()
        let capability = ContentVisibilityCapabilityAdapter(appState: appState)
        var values: [Bool] = []
        let handle = capability.addObserver { values.append($0) }

        #expect(capability.isContentViewVisible)

        appState.setDBView(false)
        #expect(values == [false])
        #expect(!capability.isContentViewVisible)

        handle.cancel()
        appState.setDBView(true)
        #expect(values == [false])
    }

    @Test
    func missingAppStateDegradesGracefully() {
        let capability = ContentVisibilityCapabilityAdapter(appState: nil)
        #expect(!capability.isContentViewVisible)
        capability.addObserver { _ in }.cancel()
    }
}

// MARK: - ViewModel 引导结论
/// 引导只在「仓库为空」且「仓库视图还没展开」时出现。
@MainActor
struct RepositoryGuidanceViewModelTests {
    @Test
    func guidanceShowsWhenRepositoryIsEmptyAndHidden() {
        let viewModel = ControlButtonsViewModel(playback: nil, targetScene: .music)
        #expect(!viewModel.shouldShowRepositoryGuidance)

        viewModel.applyRepositoryState(.empty)
        #expect(viewModel.shouldShowRepositoryGuidance)
    }

    @Test
    func guidanceHidesWhenRepositoryHasContent() {
        let viewModel = ControlButtonsViewModel(playback: nil, targetScene: .music)
        viewModel.applyRepositoryState(.empty)
        #expect(viewModel.shouldShowRepositoryGuidance)

        viewModel.applyRepositoryState(.filled)
        #expect(!viewModel.shouldShowRepositoryGuidance)
    }

    @Test
    func guidanceHidesWhenRepositoryViewIsAlreadyVisible() {
        let viewModel = ControlButtonsViewModel(playback: nil, targetScene: .music)
        viewModel.applyRepositoryState(.empty)
        #expect(viewModel.shouldShowRepositoryGuidance)

        // 仓库视图已经展开：用户自己就能看到空态页面，不再浮提示。
        viewModel.applyContentVisibility(true)
        #expect(!viewModel.shouldShowRepositoryGuidance)

        viewModel.applyContentVisibility(false)
        #expect(viewModel.shouldShowRepositoryGuidance)
    }
}

// MARK: - 气泡渲染

/// 引导气泡挂在真实按钮上方：开启时按钮上方必须多出内容，关闭时必须干净。
@MainActor
struct MoreButtonGuidanceRenderTests {
    private let background = Color(red: 0.9, green: 0.4, blue: 0.1)

    /// 渲染「按钮 + 上方留白」的整体画面，取像素数据。
    private func render(showsGuidance: Bool) throws -> CGImage {
        let view = VStack(spacing: 0) {
            Color.clear.frame(height: 80)
            MoreButtonGuidanceView(size: 44, showsGuidance: showsGuidance) {}
        }
        .frame(width: 260, height: 140)
        .background(background)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    /// 统计按钮上方区域里「与背景不同」的像素数量。
    private func contentPixelCount(in image: CGImage, aboveHeight: Int) throws -> Int {
        let data = try #require(image.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(data))
        let backgroundPixel = pixel(in: image, bytes: bytes, x: 2, y: 2)
        var count = 0
        for y in 0 ..< min(aboveHeight, image.height) {
            for x in 0 ..< image.width {
                let probe = pixel(in: image, bytes: bytes, x: x, y: y)
                if abs(probe.red - backgroundPixel.red) > 12
                    || abs(probe.green - backgroundPixel.green) > 12
                    || abs(probe.blue - backgroundPixel.blue) > 12 {
                    count += 1
                }
            }
        }
        return count
    }

    private func pixel(
        in image: CGImage,
        bytes: UnsafePointer<UInt8>,
        x: Int,
        y: Int
    ) -> (red: Int, green: Int, blue: Int) {
        let offset = (y * image.width + x) * 4
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
    }

    @Test
    func guidanceAddsContentAboveTheButton() throws {
        let withGuidance = try render(showsGuidance: true)
        let withoutGuidance = try render(showsGuidance: false)

        let guidedCount = try contentPixelCount(in: withGuidance, aboveHeight: 70)
        let plainCount = try contentPixelCount(in: withoutGuidance, aboveHeight: 70)

        #expect(guidedCount > plainCount)
        #expect(guidedCount > 100)
    }

    @Test
    func buttonRowStaysBlankWithoutGuidance() throws {
        let withoutGuidance = try render(showsGuidance: false)
        let plainCount = try contentPixelCount(in: withoutGuidance, aboveHeight: 70)
        #expect(plainCount == 0)
    }
}
