import Foundation

public extension Notification.Name {
    static let AudioLikeStatusChanged = Notification.Name("AudioLikeStatusChanged")
}

public extension NotificationCenter {
    static func postAudioLikeStatusChanged(audioId: String, url: URL, liked: Bool) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .AudioLikeStatusChanged,
                object: nil,
                userInfo: [
                    "audioId": audioId,
                    "url": url,
                    "liked": liked,
                ]
            )
        }
    }
}
