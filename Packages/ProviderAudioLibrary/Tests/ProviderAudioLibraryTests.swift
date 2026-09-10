import Testing
@testable import ProviderAudioLibrary

@Test @MainActor
func audioLibraryNoopObserverCanBeCancelled() {
    let handle = NoopAudioLibraryProvidingObserverHandle()
    handle.cancel()
    #expect(true)
}

@Test
func unavailableLibraryErrorIsTransportSafe() {
    let error = AudioLibraryProvidingError.unavailable
    #expect(error is AudioLibraryProvidingError)
}
