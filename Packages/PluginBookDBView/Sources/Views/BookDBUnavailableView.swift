import CisumUIComponents
import LumiUI
import SwiftUI

struct BookDBUnavailableView: View {
    let errorDescription: String

    var body: some View {
        Group {
            AppEmptyState(
                icon: "exclamationmark.triangle",
                title: String(localized: "Book repository is unavailable", bundle: .module),
                description: String(localized: "Database location could not be opened: \(errorDescription)", bundle: .module)
            )
            .accessibilityIdentifier("cisum.scene.audiobooks.unavailable")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.scene.audiobooks")
    }
}
