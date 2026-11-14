import Foundation
import Testing

@testable import MagicKit

private struct TestEmitter: SuperEvent {}

private final class ObserverTokenBox: @unchecked Sendable {
    var token: NSObjectProtocol?
}

@Test func superEventDeliversBackgroundEmitsOnMainThread() async {
    let name = Notification.Name("SuperEventBackgroundEmitTest.\(UUID().uuidString)")
    let emitter = TestEmitter()
    let tokenBox = ObserverTokenBox()

    let deliveredOnMain = await withCheckedContinuation { continuation in
        tokenBox.token = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: nil
        ) { _ in
            continuation.resume(returning: Thread.isMainThread)
        }

        DispatchQueue.global(qos: .background).async {
            emitter.emit(name: name)
        }
    }

    if let token = tokenBox.token {
        NotificationCenter.default.removeObserver(token)
    }

    #expect(deliveredOnMain)
}
