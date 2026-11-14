import CloudKit
import Foundation
import OSLog
import SwiftData

/// 可以与 CloudKit 同步
public protocol SuperCloudModel: Hashable, Equatable {
    var uuid: String { get }
    var privateRecordID: CKRecord.ID { get }
    var zone: CKRecordZone { get }
    var recordType: CKRecord.RecordType { get }
    var debugTitle: String { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

// MARK: Identifiable

extension SuperCloudModel {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
