import XCTest
@testable import ProviderToast

@MainActor
private final class ToastSpy: ToastProviding {
    private(set) var shownToasts: [CisumToast] = []
    private(set) var presentedErrors: [CisumErrorNotice] = []

    func show(_ toast: CisumToast) { shownToasts.append(toast) }
    func presentError(title: String, message: String) {
        presentedErrors.append(CisumErrorNotice(title: title, message: message))
    }
    func dismissError() {}
    func showLoading(title: String, detail: String?) {}
    func dismissLoading() {}
    func dismissAll() {}
}

@MainActor
final class ProviderToastTests: XCTestCase {
    func testToastValueSemantics() {
        let toast = CisumToast(title: "Saved", detail: "Track", style: .success, duration: 2)
        XCTAssertEqual(toast, CisumToast(title: "Saved", detail: "Track", style: .success, duration: 2))
    }

    func testToastConvenienceMethodPreservesAllOptions() {
        let provider = ToastSpy()

        provider.show("Import complete", detail: "3 tracks", style: .success, duration: 4)

        XCTAssertEqual(
            provider.shownToasts,
            [CisumToast(title: "Import complete", detail: "3 tracks", style: .success, duration: 4)]
        )
    }

    func testSeverityConveniencesUseToastOrPersistentErrorPresentation() {
        let provider = ToastSpy()

        provider.info("Info")
        provider.success("Saved")
        provider.warning("Careful")
        provider.error("Failed", detail: "Try again", duration: 2)
        provider.error("Unavailable", detail: "Storage missing")

        XCTAssertEqual(provider.shownToasts.map(\.style), [.info, .success, .warning, .error])
        XCTAssertEqual(provider.shownToasts.map(\.duration), [3, 3, 4, 2])
        XCTAssertEqual(provider.presentedErrors.map(\.title), ["Unavailable"])
        XCTAssertEqual(provider.presentedErrors.map(\.message), ["Storage missing"])
    }

    func testNoticeValueTypesPreserveIdentityAndOptionalDetails() {
        let id = UUID()
        let error = CisumErrorNotice(id: id, title: "Failed", message: "Disk full")
        let loading = CisumLoadingNotice(title: "Loading")

        XCTAssertEqual(error.id, id)
        XCTAssertEqual(error, CisumErrorNotice(id: id, title: "Failed", message: "Disk full"))
        XCTAssertNil(loading.detail)
        XCTAssertEqual(loading, CisumLoadingNotice(title: "Loading"))
        XCTAssertNotEqual(CisumErrorNotice(title: "Failed", message: "Disk full").id, id)
    }

    func testToastStylesKeepStableRawValues() {
        XCTAssertEqual(CisumToastStyle.info.rawValue, "info")
        XCTAssertEqual(CisumToastStyle.success.rawValue, "success")
        XCTAssertEqual(CisumToastStyle.warning.rawValue, "warning")
        XCTAssertEqual(CisumToastStyle.error.rawValue, "error")
    }

    func testDefaultProviderIsNoOp() {
        let provider = DefaultToastProvider()
        provider.show("Info")
        provider.presentError(title: "Error", message: "Details")
        provider.dismissError()
        provider.showLoading(title: "Loading", detail: nil)
        provider.dismissLoading()
        provider.dismissAll()
    }
}
