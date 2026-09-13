import Foundation
import ProviderToast
import Testing
@testable import PluginToast

@MainActor
struct ToastProviderTests {
    @Test
    func showSetsCurrentToast() {
        let provider = ToastProvider()
        let toast = CisumToast(title: "Saved", detail: nil, duration: 0)

        provider.show(toast)
        #expect(provider.currentToast == toast)
    }

    @Test
    func showWithZeroDurationStaysVisible() async throws {
        let provider = ToastProvider()
        provider.show(CisumToast(title: "Sticky", duration: 0))
        try await Task.sleep(for: .milliseconds(150))
        #expect(provider.currentToast != nil)
    }

    @Test
    func showWithDurationAutoDismisses() async throws {
        let provider = ToastProvider()
        provider.show(CisumToast(title: "Brief", duration: 0.1))
        #expect(provider.currentToast != nil)

        try await Task.sleep(for: .milliseconds(300))
        #expect(provider.currentToast == nil)
    }

    @Test
    func showClearsLoadingAndReplacesToast() async throws {
        let provider = ToastProvider()
        provider.showLoading(title: "Loading", detail: "Scanning")
        provider.show(CisumToast(title: "New", duration: 0))

        #expect(provider.currentLoading == nil)
        #expect(provider.currentToast?.title == "New")
    }

    @Test
    func errorPresentationAndDismissal() {
        let provider = ToastProvider()
        provider.presentError(title: "Oops", message: "Failed")
        #expect(provider.currentError?.title == "Oops")
        #expect(provider.currentError?.message == "Failed")

        provider.dismissError()
        #expect(provider.currentError == nil)
    }

    @Test
    func loadingPresentationClearsToast() {
        let provider = ToastProvider()
        provider.show(CisumToast(title: "Old", duration: 0))
        provider.showLoading(title: "Loading", detail: "Sync")

        #expect(provider.currentToast == nil)
        #expect(provider.currentLoading?.title == "Loading")
        #expect(provider.currentLoading?.detail == "Sync")

        provider.dismissLoading()
        #expect(provider.currentLoading == nil)
    }

    @Test
    func dismissAllClearsEverything() {
        let provider = ToastProvider()
        provider.show(CisumToast(title: "T", duration: 0))
        provider.presentError(title: "E", message: "M")
        provider.showLoading(title: "L", detail: nil)

        provider.dismissAll()
        #expect(provider.currentToast == nil)
        #expect(provider.currentError == nil)
        #expect(provider.currentLoading == nil)
    }

    @Test
    func newToastCancelsPendingDismissal() async throws {
        let provider = ToastProvider()
        provider.show(CisumToast(title: "First", duration: 0.1))
        provider.show(CisumToast(title: "Second", duration: 0))

        // 第一个的定时清除任务被取消；第二个保持可见。
        try await Task.sleep(for: .milliseconds(250))
        #expect(provider.currentToast?.title == "Second")
    }
}
