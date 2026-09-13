import Foundation
import CisumUIComponents
import OSLog
import SwiftUI
import ProviderAudioLibrary

public struct AudioDBRootView<Content>: View, SuperLog where Content: View {
    public nonisolated static var emoji: String { "🎵" }
    public nonisolated static var verbose: Bool { true }

    @ObservedObject private var rootViewModel: AudioDBRootViewModel
    private let isDemoMode: Bool

    private var content: Content

    init(
        isDemoMode: Bool,
        rootViewModel: AudioDBRootViewModel,
        @ViewBuilder content: () -> Content
    ) {
        self.isDemoMode = isDemoMode
        self._rootViewModel = ObservedObject(wrappedValue: rootViewModel)
        self.content = content()
    }

    public var body: some View {
        if isDemoMode {
            content
        } else {
            content
                .task {
                    await rootViewModel.checkAudioRepo()
                }
        }
    }
}
