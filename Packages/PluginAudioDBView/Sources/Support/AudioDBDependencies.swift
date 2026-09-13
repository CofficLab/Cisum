import ProviderAudioLibrary
import SwiftUI

public struct AudioDBDependencies: @unchecked Sendable {
    public var audioLibrary: @MainActor @Sendable () -> (any AudioLibraryProviding)?
    public var audioDisk: @MainActor @Sendable () -> URL?
    public var audioDiagnostics: @MainActor @Sendable () -> AudioStorageDiagnostics
    public var supportedExtensions: [String]
    public var isDesktop: Bool
    public var isNotDesktop: Bool
    public var showDBView: @MainActor @Sendable () -> Void
    public var isImporting: Binding<Bool>

    public init(
        audioLibrary: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?,
        audioDisk: @escaping @MainActor @Sendable () -> URL?,
        audioDiagnostics: @escaping @MainActor @Sendable () -> AudioStorageDiagnostics,
        supportedExtensions: [String],
        isDesktop: Bool,
        isNotDesktop: Bool,
        showDBView: @escaping @MainActor @Sendable () -> Void,
        isImporting: Binding<Bool>
    ) {
        self.audioLibrary = audioLibrary
        self.audioDisk = audioDisk
        self.audioDiagnostics = audioDiagnostics
        self.supportedExtensions = supportedExtensions
        self.isDesktop = isDesktop
        self.isNotDesktop = isNotDesktop
        self.showDBView = showDBView
        self.isImporting = isImporting
    }

    public static let empty = AudioDBDependencies(
        audioLibrary: { nil },
        audioDisk: { nil },
        audioDiagnostics: { AudioStorageDiagnosticsFactory.make(storage: nil) },
        supportedExtensions: [],
        isDesktop: true,
        isNotDesktop: false,
        showDBView: {},
        isImporting: .constant(false)
    )
}
