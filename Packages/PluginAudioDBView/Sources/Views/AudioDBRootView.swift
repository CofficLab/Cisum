import Foundation
import CisumUIComponents
import OSLog
import SwiftUI
import ProviderAudioLibrary

public struct AudioDBRootView<Content>: View, SuperLog where Content: View {
    public nonisolated static var emoji: String { "🎵" }
    public nonisolated static var verbose: Bool { true }

    @EnvironmentObject private var rootViewModel: AudioDBRootViewModel
    @Environment(\.audioDBDependencies) private var dependencies
    private let isDemoMode: Bool

    private var content: Content

    public init(isDemoMode: Bool, @ViewBuilder content: () -> Content) {
        self.isDemoMode = isDemoMode
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
