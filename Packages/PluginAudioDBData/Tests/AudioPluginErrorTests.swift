import Foundation
import Testing
@testable import PluginAudioDBData

@Test
func audioPluginErrorsProvideUserFacingRecoveryDetails() {
    let file = URL(fileURLWithPath: "/library/track.mp3")
    let errors: [any LocalizedError] = [
        AudioPluginError.hostNotConfigured,
        AudioPluginError.NoNextAsset,
        AudioPluginError.NoPrevAsset,
        AudioPluginError.NoDisk,
        AudioPluginError.initialization(reason: "container unavailable"),
        AudioPluginError.diskAccess(url: file, underlying: "permission denied"),
        AudioPluginError.configurationError(setting: "library", reason: "missing"),
    ]

    for error in errors {
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.failureReason?.isEmpty == false)
        #expect(error.recoverySuggestion?.isEmpty == false)
    }
}

@Test
func audioRecordDatabaseErrorsDescribeUnderlyingFailures() {
    let file = URL(fileURLWithPath: "/library/track.mp3")
    let underlying = NSError(domain: "AudioTests", code: 7, userInfo: [NSLocalizedDescriptionKey: "disk full"])
    let errors: [any LocalizedError] = [
        AudioRecordDBError.ToggleLikeError(underlying),
        AudioRecordDBError.AudioNotFound(file),
        AudioRecordDBError.databaseOperation(operation: "fetch", underlying: "database locked"),
        AudioRecordDBError.saveFailed(underlying),
        AudioRecordDBError.deleteFailed(underlying),
    ]

    for error in errors {
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.failureReason?.isEmpty == false)
        #expect(error.recoverySuggestion?.isEmpty == false)
    }
}

@Test
func audioModelErrorsProvideSpecificRecoveryDetails() {
    let file = URL(fileURLWithPath: "/library/track.mp3")
    let errors: [any LocalizedError] = [
        AudioModelError.deleteFailed,
        AudioModelError.dbNotFound,
        AudioModelError.invalidData("missing title"),
        AudioModelError.fileCorrupted(file),
    ]

    for error in errors {
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.failureReason?.isEmpty == false)
        #expect(error.recoverySuggestion?.isEmpty == false)
    }
}

@Test
func audioRepositoryErrorsProvideOperationalRecoveryDetails() {
    let endpoint = URL(string: "https://example.com/audio.mp3")!
    let errors: [any LocalizedError] = [
        AudioRepoError.fileSystemError(operation: "scan", path: "/library"),
        AudioRepoError.networkError(url: endpoint, underlying: "offline"),
        AudioRepoError.invalidState(expected: "ready", actual: "stopped"),
        AudioRepoError.syncFailed(NSError(domain: "AudioTests", code: 8)),
        AudioRepoError.monitorFailed(NSError(domain: "AudioTests", code: 9)),
    ]

    for error in errors {
        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.failureReason?.isEmpty == false)
        #expect(error.recoverySuggestion?.isEmpty == false)
    }
}
