import Foundation
import OSLog
import SwiftData
import MagicKit


extension DBSynced {
    func insertDeviceData(deviceId: String) {
        let deviceData = DeviceData(uuid: deviceId)
        deviceData.firstOpenTime = .now
        deviceData.lastOpenTime = .now
        deviceData.name = MagicApp.getDeviceName()
        deviceData.model = MagicApp.getDeviceModel()
        deviceData.os = MagicApp.getSystemName()
        deviceData.version = MagicApp.getSystemVersion()
        
        do {
            self.context.insert(deviceData)
            try self.context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }
    
    func saveDeviceData(uuid: String, audioCount: Int) {
        if let deviceData = self.find(uuid) {
            deviceData.timesOpened += 1
            deviceData.lastOpenTime = .now
            deviceData.audioCount = audioCount
            
            do {
                try context.save()
            } catch let e {
                os_log(.error, "\(e.localizedDescription)")
            }
        } else {
            insertDeviceData(deviceId: uuid)
        }
    }
    
    // MARK: Delete
    
    func deleteDevice(_ deviceData: DeviceData) {
        os_log("\(self.t)Delete Device -> \(deviceData.name)")
        
        guard let dbItem = context.model(for: deviceData.id) as? DeviceData else {
            return
        }
        
        context.delete(dbItem)
        
        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }
    
    // MARK: Read
    
    func find(_ uuid: String) -> DeviceData? {
        do {
            return try context.fetch(FetchDescriptor(predicate: #Predicate<DeviceData> {
                $0.uuid == uuid
            })).first
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
            
            return nil
        }
    }
    
    func allDevices() -> [DeviceData] {
        do {
            return try context.fetch(DeviceData.descriptorAll)
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
            
            return []
        }
    }
}
