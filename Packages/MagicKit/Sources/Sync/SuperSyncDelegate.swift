import Foundation
import CloudKit

@preconcurrency
public protocol SuperSyncDelegate: Actor {
    func onGetModel(recordID: CKRecord.ID) async throws -> CKRecord?
    func onMerge(record: CKRecord) async
    func onDelete(deletion: CKDatabase.RecordZoneChange.Deletion) async
    func onSaved(record: CKRecord)
    func onClearLastKnownRecord(_ record: CKRecord)
    func onGetAll() async -> [any SuperCloudModel]
    func onWillFetchChanges()
    func onDidFetchChanges()
    func onWillSendChanges()
    func onDidSendChanges()
    func onCloudStateSaveFailed(error: CloudState.Error)
}
