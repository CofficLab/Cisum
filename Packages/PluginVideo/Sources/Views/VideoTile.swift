import CisumUIComponents
import LumiUI
import SwiftUI

struct VideoFileSizeLoadPolicy {
    static func shouldApplySize(currentFile: URL, requestedFile: URL) -> Bool {
        currentFile.isSameFileLocation(as: requestedFile)
    }
}

struct VideoFileActionPolicy {
    static func canOpen(
        _ file: URL,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> Bool {
        guard file.isFileURL else { return true }
        return fileExists(file.path)
    }
}

struct VideoTileAccessibilityPolicy {
    static func selectionLabel(fileTitle: String) -> String {
        String(localized: "Select \(fileTitle)", bundle: .module)
    }
}

public struct VideoTile: View {
    @Binding private var selection: URL?
    @State private var fileSize: String?
    @State private var fileUnavailable = false

    private let file: URL

    public init(selection: Binding<URL?>, file: URL) {
        _selection = selection
        self.file = file
    }

    public var body: some View {
        HStack {
            Image(systemName: "video")
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.title)

                if file.isNotFolder {
                    Text(fileSizeText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if VideoFileActionPolicy.canOpen(file) {
                file.makeOpenButton()
                    .labelStyle(.iconOnly)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selection = file
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(VideoTileAccessibilityPolicy.selectionLabel(fileTitle: file.title))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            selection = file
        }
        .help(VideoTileAccessibilityPolicy.selectionLabel(fileTitle: file.title))
        .task(id: file, priority: .background) {
            await loadFileSize()
        }
    }

    private var fileSizeText: String {
        if fileUnavailable {
            return String(localized: "Unavailable", bundle: .module)
        }

        return fileSize ?? String(localized: "Calculating...", bundle: .module)
    }

    private func loadFileSize() async {
        fileSize = nil
        fileUnavailable = false

        guard file.isNotFolder else { return }

        let requestedFile = file
        guard Self.canReadSize(for: requestedFile) else {
            fileUnavailable = true
            return
        }

        let size = await Self.readableFileSize(for: requestedFile)

        guard !Task.isCancelled,
              VideoFileSizeLoadPolicy.shouldApplySize(currentFile: file, requestedFile: requestedFile) else {
            return
        }

        guard Self.canReadSize(for: requestedFile) else {
            fileUnavailable = true
            return
        }

        fileSize = size
    }

    nonisolated private static func canReadSize(for file: URL) -> Bool {
        VideoFileActionPolicy.canOpen(file)
    }

    nonisolated static func readableFileSize(for file: URL) async -> String {
        await Task.detached(priority: .utility) {
            file.getSizeReadable()
        }.value
    }
}
