import SwiftUI

public extension Error {
    /// Render an error as a compact SwiftUI view.
    func makeView() -> AnyView {
        AnyView(VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.red)
                .accessibilityHidden(true)

            Text(String(localized: "An error occurred", bundle: .module))
                .font(.headline)

            Text(localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding())
    }
}
