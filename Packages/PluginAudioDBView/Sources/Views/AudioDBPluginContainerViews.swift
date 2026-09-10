import ProviderAudioLibrary
import SwiftUI

struct AudioDBPluginRootView<Content>: View where Content: View {
    @Environment(\.demoMode) private var isDemoMode
    @Environment(\.appIsImporting) private var isImporting
    @Environment(\.showAudioDBViewAction) private var showDBView
    let listViewModel: AudioListViewModel
    let rootViewModel: AudioDBRootViewModel
    let dbViewModel: AudioDBViewModel
    @ObservedObject var sceneState: AudioDBSceneState

    private let audioLibrary: @MainActor @Sendable () -> (any AudioLibraryProviding)?
    private let audioDisk: @MainActor @Sendable () -> URL?
    private let audioDiagnostics: @MainActor @Sendable () -> AudioStorageDiagnostics

    private let content: Content

    init(
        listViewModel: AudioListViewModel,
        rootViewModel: AudioDBRootViewModel,
        dbViewModel: AudioDBViewModel,
        sceneState: AudioDBSceneState,
        audioLibrary: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?,
        audioDisk: @escaping @MainActor @Sendable () -> URL?,
        audioDiagnostics: @escaping @MainActor @Sendable () -> AudioStorageDiagnostics,
        @ViewBuilder content: () -> Content
    ) {
        self.listViewModel = listViewModel
        self.rootViewModel = rootViewModel
        self.dbViewModel = dbViewModel
        self.sceneState = sceneState
        self.audioLibrary = audioLibrary
        self.audioDisk = audioDisk
        self.audioDiagnostics = audioDiagnostics
        self.content = content()
    }

    var body: some View {
        if sceneState.isMusicScene {
            AudioDBRootView(isDemoMode: isDemoMode) {
                content
            }
            .environment(\.audioDBDependencies, dependencies)
            .environmentObject(listViewModel)
            .environmentObject(rootViewModel)
            .environmentObject(dbViewModel)
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
    @Environment(\.appIsImporting) private var isImporting
    @Environment(\.showAudioDBViewAction) private var showDBView
    let listViewModel: AudioListViewModel
    let rootViewModel: AudioDBRootViewModel
    let dbViewModel: AudioDBViewModel

    private let audioLibrary: @MainActor @Sendable () -> (any AudioLibraryProviding)?
    private let audioDisk: @MainActor @Sendable () -> URL?
    private let audioDiagnostics: @MainActor @Sendable () -> AudioStorageDiagnostics

    let demoMode: Bool

    init(
        listViewModel: AudioListViewModel,
        rootViewModel: AudioDBRootViewModel,
        dbViewModel: AudioDBViewModel,
        audioLibrary: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?,
        audioDisk: @escaping @MainActor @Sendable () -> URL?,
        audioDiagnostics: @escaping @MainActor @Sendable () -> AudioStorageDiagnostics,
        demoMode: Bool
    ) {
        self.listViewModel = listViewModel
        self.rootViewModel = rootViewModel
        self.dbViewModel = dbViewModel
        self.audioLibrary = audioLibrary
        self.audioDisk = audioDisk
        self.audioDiagnostics = audioDiagnostics
        self.demoMode = demoMode
    }

    var body: some View {
        AudioDBView(isDemoMode: demoMode)
            .environment(\.audioDBDependencies, dependencies)
            .environmentObject(listViewModel)
            .environmentObject(rootViewModel)
            .environmentObject(dbViewModel)
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
