import ProviderAudioLibrary
import SwiftUI

struct AudioDBPluginRootView<Content>: View where Content: View {
    let listViewModel: AudioListViewModel
    let rootViewModel: AudioDBRootViewModel
    let dbViewModel: AudioDBViewModel
    @ObservedObject var sceneState: AudioDBSceneState

    private let audioLibrary: @MainActor @Sendable () -> (any AudioLibraryProviding)?
    private let audioDisk: @MainActor @Sendable () -> URL?
    private let audioDiagnostics: @MainActor @Sendable () -> AudioStorageDiagnostics
    private let isDemoMode: Bool
    private let isImporting: Binding<Bool>
    private let showDBView: @MainActor @Sendable () -> Void

    private let content: Content

    init(
        listViewModel: AudioListViewModel,
        rootViewModel: AudioDBRootViewModel,
        dbViewModel: AudioDBViewModel,
        sceneState: AudioDBSceneState,
        audioLibrary: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?,
        audioDisk: @escaping @MainActor @Sendable () -> URL?,
        audioDiagnostics: @escaping @MainActor @Sendable () -> AudioStorageDiagnostics,
        isDemoMode: Bool,
        isImporting: Binding<Bool>,
        showDBView: @escaping @MainActor @Sendable () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.listViewModel = listViewModel
        self.rootViewModel = rootViewModel
        self.dbViewModel = dbViewModel
        self.sceneState = sceneState
        self.audioLibrary = audioLibrary
        self.audioDisk = audioDisk
        self.audioDiagnostics = audioDiagnostics
        self.isDemoMode = isDemoMode
        self.isImporting = isImporting
        self.showDBView = showDBView
        self.content = content()
    }

    var body: some View {
        if sceneState.isMusicScene {
            AudioDBRootView(isDemoMode: isDemoMode, rootViewModel: rootViewModel) {
                content
            }
        } else {
            // 场景不是音乐库：下掉 AudioDB root view 外壳，直接透传内容区。
            content
        }
    }

    private var dependencies: AudioDBDependencies {
        AudioDBDependencies(
            audioLibrary: audioLibrary,
            audioDisk: audioDisk,
            audioDiagnostics: audioDiagnostics,
            supportedExtensions: AudioPluginInfo.supportedExtensions,
            isDesktop: Self.isDesktop,
            isNotDesktop: !Self.isDesktop,
            showDBView: showDBView,
            isImporting: isImporting
        )
    }

    private static var isDesktop: Bool {
        #if os(macOS)
            true
        #else
            false
        #endif
    }
}

struct AudioDBPluginTabView: View {
    let listViewModel: AudioListViewModel
    let rootViewModel: AudioDBRootViewModel
    let dbViewModel: AudioDBViewModel

    private let audioLibrary: @MainActor @Sendable () -> (any AudioLibraryProviding)?
    private let audioDisk: @MainActor @Sendable () -> URL?
    private let audioDiagnostics: @MainActor @Sendable () -> AudioStorageDiagnostics
    private let isImporting: Binding<Bool>
    private let showDBView: @MainActor @Sendable () -> Void

    let demoMode: Bool

    init(
        listViewModel: AudioListViewModel,
        rootViewModel: AudioDBRootViewModel,
        dbViewModel: AudioDBViewModel,
        audioLibrary: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?,
        audioDisk: @escaping @MainActor @Sendable () -> URL?,
        audioDiagnostics: @escaping @MainActor @Sendable () -> AudioStorageDiagnostics,
        isImporting: Binding<Bool>,
        showDBView: @escaping @MainActor @Sendable () -> Void,
        demoMode: Bool
    ) {
        self.listViewModel = listViewModel
        self.rootViewModel = rootViewModel
        self.dbViewModel = dbViewModel
        self.audioLibrary = audioLibrary
        self.audioDisk = audioDisk
        self.audioDiagnostics = audioDiagnostics
        self.isImporting = isImporting
        self.showDBView = showDBView
        self.demoMode = demoMode
    }

    var body: some View {
        AudioDBView(
            isDemoMode: demoMode,
            listViewModel: listViewModel,
            dbViewModel: dbViewModel,
            dependencies: dependencies
        )
    }

    private var dependencies: AudioDBDependencies {
        AudioDBDependencies(
            audioLibrary: audioLibrary,
            audioDisk: audioDisk,
            audioDiagnostics: audioDiagnostics,
            supportedExtensions: AudioPluginInfo.supportedExtensions,
            isDesktop: Self.isDesktop,
            isNotDesktop: !Self.isDesktop,
            showDBView: showDBView,
            isImporting: isImporting
        )
    }

    private static var isDesktop: Bool {
        #if os(macOS)
            true
        #else
            false
        #endif
    }
}
