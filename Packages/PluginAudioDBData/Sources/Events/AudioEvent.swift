import Foundation

public extension Notification.Name {
    static let dbSyncing = Notification.Name("dbSyncing")
    static let dbSynced = Notification.Name("dbSynced")
    static let dbUpdated = Notification.Name("dbUpdated")
    static let dbDeleted = Notification.Name("dbDeleted")
    static let DBSorting = Notification.Name("DBSorting")
    static let DBSortDone = Notification.Name("DBSortDone")
}

public extension NotificationCenter {
    static func postDBSyncing() {
        postAudioEventOnMain(name: .dbSyncing)
    }

    static func postDBSynced() {
        postAudioEventOnMain(name: .dbSynced)
    }

    static func postDBUpdated() {
        postAudioEventOnMain(name: .dbUpdated)
    }

    private static func postAudioEventOnMain(name: Notification.Name) {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: name, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: name, object: nil)
            }
        }
    }
}
