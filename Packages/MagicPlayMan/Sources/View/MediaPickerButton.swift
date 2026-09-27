import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

struct MediaPickerButton: View {
    let man: MagicPlayMan
    let selectedName: String?
    let onSelect: (URL) -> Void

    @Environment(\.localization) private var loc

    private var accessibilityTitle: String {
        MediaPickerButtonAccessibilityPolicy.label(
            selectedName: selectedName,
            selectMediaText: loc.selectMedia
        )
    }

    var body: some View {
        Menu {
            ForEach(man.samples, id: \.self) { sample in
                Button {
                    onSelect(sample)
                } label: {
                    Label(
                        sample.title,
                        systemImage: sample.systemIcon
                    )
                }
            }
        } label: {
            HStack {
                Image(systemName: PlaybackSymbol.play)
                Text(selectedName ?? loc.selectMedia)
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .accessibilityLabel(accessibilityTitle)
            .help(accessibilityTitle)
        }
    }
}

enum MediaPickerButtonAccessibilityPolicy {
    static func label(selectedName: String?, selectMediaText: String) -> String {
        guard let selectedName = selectedName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selectedName.isEmpty
        else {
            return selectMediaText
        }

        return "\(selectMediaText): \(selectedName)"
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}
