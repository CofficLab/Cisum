import XCTest
import KernelCore
import ProviderRootView
import ProviderToast
@testable import PluginToast

@MainActor
final class PluginToastTests: XCTestCase {
    func testShowReplacesCurrentToast() {
        let center = ToastProvider()
        center.show("First")
        center.show("Second", style: .success)
        XCTAssertEqual(center.currentToast?.title, "Second")
        XCTAssertEqual(center.currentToast?.style, .success)
    }

    func testErrorIsPersistentUntilDismissed() {
        let center = ToastProvider()
        center.presentError(title: "Failure", message: "Details")
        XCTAssertEqual(center.currentError?.message, "Details")
        center.dismissError()
        XCTAssertNil(center.currentError)
    }

    func testPluginRegistersProviderAndRootOverlay() async throws {
        let kernel = CisumKernel()
        let root = DefaultRootViewProvider(kernel: kernel)
        try kernel.registerProvider((any RootViewProviding).self, root)
        let plugin = ToastPlugin()

        try await plugin.onBoot(kernel: kernel)

        let center = await plugin.center
        XCTAssertTrue((kernel.toast as AnyObject?) === center)
        XCTAssertEqual(root.overlays.map(\.id), ["cisum.toast"])

        try await plugin.onShutdown(kernel: kernel)
        XCTAssertTrue(root.overlays.isEmpty)
    }
}
