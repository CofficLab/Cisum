import XCTest
@testable import ProviderToast

@MainActor
final class ProviderToastTests: XCTestCase {
    func testToastValueSemantics() {
        let toast = CisumToast(title: "Saved", detail: "Track", style: .success, duration: 2)
        XCTAssertEqual(toast, CisumToast(title: "Saved", detail: "Track", style: .success, duration: 2))
    }

    func testDefaultProviderIsNoOp() {
        let provider = DefaultToastProvider()
        provider.show("Info")
        provider.presentError(title: "Error", message: "Details")
        provider.showLoading(title: "Loading", detail: nil)
        provider.dismissAll()
    }
}
