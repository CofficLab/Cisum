import Foundation
import ProviderAudioLibrary
import ProviderStorage

@MainActor
enum AudioStorageDiagnosticsFactory {
    static func make(storage: (any StorageProviding)?) -> AudioStorageDiagnostics {
        let storageLocationRaw = UserDefaults.standard.string(forKey: "StorageLocation")
        let isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        let cloudContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil)
        let cloudDocuments = cloudContainer?.appendingPathComponent("Documents")
        let localDocuments = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storageRoot = storage?.storageRoot
        let disk = storageRoot?.appendingPathComponent(
            AudioPluginInfo.effectiveDBDirName,
            isDirectory: true
        )

        return AudioStorageDiagnostics(
            storageLocationRaw: storageLocationRaw,
            isICloudAvailable: isICloudAvailable,
            hasUsableStorageLocation: storage?.hasUsableStorageLocation ?? false,
            cloudContainer: cloudContainer?.path,
            cloudDocuments: cloudDocuments?.path,
            localDocuments: localDocuments?.path,
            storageRoot: storageRoot?.path,
            audioDisk: disk?.path,
            dbDirName: AudioPluginInfo.effectiveDBDirName
        )
    }
}
