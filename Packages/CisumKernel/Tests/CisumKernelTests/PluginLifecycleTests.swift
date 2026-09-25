import CisumUIComponents
import Foundation
import Testing
@testable import CisumKernel

// MARK: - 生命周期测试探针

enum LifecycleTestError: Error {
    case bootFailed
    case readyFailed
}

/// 每次测试独立使用的调用记录器（避免并行测试共享全局状态）。
final class CallRecorder {
    var calls: [String] = []
    func record(_ call: String) { calls.append(call) }
}

/// 测试探针插件：记录全部生命周期回调，可配置在 Boot / Ready 阶段抛错。
actor LifecycleProbePlugin: SuperPlugin {
    nonisolated let recorder: CallRecorder
    let name: String
    let orderValue: Int
    let failOnBoot: Bool
    let failOnReady: Bool

    init(recorder: CallRecorder, name: String, order: Int, failOnBoot: Bool = false, failOnReady: Bool = false) {
        self.recorder = recorder
        self.name = name
        self.orderValue = order
        self.failOnBoot = failOnBoot
        self.failOnReady = failOnReady
    }

    nonisolated var id: String { name }
    nonisolated static let shared: LifecycleProbePlugin = LifecycleProbePlugin(
        recorder: CallRecorder(), name: "", order: 0
    )
    nonisolated static var metadata: PluginMetadata {
        PluginMetadata(displayName: "", description: "", policy: .alwaysOn)
    }

    @MainActor
    func onRegister(kernel: CisumKernel) async throws {
        recorder.record("register.\(name)")
    }

    @MainActor
    func onBoot(kernel: CisumKernel) async throws {
        // 抛错插件不记录 boot：模拟「启动即失败」，manager 不应将其视为已 boot。
        if failOnBoot { throw LifecycleTestError.bootFailed }
        recorder.record("boot.\(name)")
    }

    @MainActor
    func onReady(kernel: CisumKernel) async throws {
        if failOnReady { throw LifecycleTestError.readyFailed }
        recorder.record("ready.\(name)")
    }

    @MainActor
    func onShutdown(kernel: CisumKernel) async throws {
        recorder.record("shutdown.\(name)")
    }

    @MainActor
    func onUnregister(kernel: CisumKernel) async throws {
        recorder.record("unregister.\(name)")
    }
}

// MARK: - 测试

@MainActor
struct PluginLifecycleTests {

    @Test
    func testNormalLifecycleCallsInOrder() async throws {
        let recorder = CallRecorder()
        let kernel = CisumKernelContainer()
        let probeA = LifecycleProbePlugin(recorder: recorder, name: "a", order: 1)
        let probeB = LifecycleProbePlugin(recorder: recorder, name: "b", order: 2)

        kernel.pluginManager.initializePlugins([probeA, probeB])
        try await kernel.pluginManager.onBoot(kernel: kernel)
        try await kernel.pluginManager.onReady(kernel: kernel)
        await kernel.pluginManager.shutdown(kernel: kernel)

        // 启动按 order 升序，停止按启动逆序。
        #expect(recorder.calls == [
            "register.a", "register.b",
            "boot.a", "boot.b",
            "ready.a", "ready.b",
            "shutdown.b", "shutdown.a",
            "unregister.b", "unregister.a",
        ])
    }

    @Test
    func testOnBootFailureRollsBackBootedPlugins() async throws {
        let recorder = CallRecorder()
        let kernel = CisumKernelContainer()
        let probeA = LifecycleProbePlugin(recorder: recorder, name: "a", order: 1)
        let probeFail = LifecycleProbePlugin(recorder: recorder, name: "fail", order: 2, failOnBoot: true)

        kernel.pluginManager.initializePlugins([probeA, probeFail])

        // 插件错误会被包装为携带插件 ID 的 pluginFailed。
        do {
            try await kernel.pluginManager.onBoot(kernel: kernel)
            Issue.record("Expected onBoot to throw")
        } catch let error as CisumKernelError {
            guard case .pluginFailed(let pluginID, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(pluginID == "fail")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // a 已 boot → 逆序 shutdown；fail 与 a 统一 unregister。
        #expect(recorder.calls == [
            "register.a", "register.fail",
            "boot.a",
            "shutdown.a",
            "unregister.fail",
            "unregister.a",
        ])

        // 回滚后注册表清空，可重新初始化。
        #expect(kernel.pluginManager.allPlugins.isEmpty)
    }

    @Test
    func testOnReadyFailureRollsBackBootedPlugins() async throws {
        let recorder = CallRecorder()
        let kernel = CisumKernelContainer()
        let probeA = LifecycleProbePlugin(recorder: recorder, name: "a", order: 1)
        let probeFail = LifecycleProbePlugin(recorder: recorder, name: "fail", order: 2, failOnReady: true)

        kernel.pluginManager.initializePlugins([probeA, probeFail])
        try await kernel.pluginManager.onBoot(kernel: kernel)

        // 插件错误会被包装为携带插件 ID 的 pluginFailed。
        do {
            try await kernel.pluginManager.onReady(kernel: kernel)
            Issue.record("Expected onReady to throw")
        } catch let error as CisumKernelError {
            guard case .pluginFailed(let pluginID, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(pluginID == "fail")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // 两个插件均已 boot → 逆序 shutdown + unregister。
        #expect(recorder.calls == [
            "register.a", "register.fail",
            "boot.a", "boot.fail",
            "ready.a",
            "shutdown.fail", "shutdown.a",
            "unregister.fail", "unregister.a",
        ])

        #expect(kernel.pluginManager.allPlugins.isEmpty)
    }

    @Test
    func testContainerShutdownExposesTeardown() async throws {
        let recorder = CallRecorder()
        let kernel = CisumKernelContainer()
        let probeA = LifecycleProbePlugin(recorder: recorder, name: "a", order: 1)

        kernel.pluginManager.initializePlugins([probeA])
        try await kernel.pluginManager.onBoot(kernel: kernel)
        await kernel.shutdown()

        #expect(recorder.calls == ["register.a", "boot.a", "shutdown.a", "unregister.a"])
        #expect(kernel.pluginManager.allPlugins.isEmpty)
    }
}
