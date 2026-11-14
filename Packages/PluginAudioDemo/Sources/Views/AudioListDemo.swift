import Foundation
import SwiftUI

public struct AudioListDemo: View {
    public static let demoAudioFiles: [String] = [
        "清风徐来.mp3",
        "夜空中最亮的星.m4a",
        "成都.flac",
        "理想.wav",
        "南山南.mp3",
        "董小姐.m4a",
        "安和桥.flac",
        "斑马斑马.wav",
        "平凡之路.mp3",
        "童话镇.m4a",
        "追光者.flac",
        "消愁.wav",
        "演员.mp3",
        "体面.m4a",
        "说散就散.flac",
        "往后余生.wav",
        "像我这样的人.mp3",
        "起风了.m4a",
        "少年.flac",
        "岁月神偷.wav",
    ]

    private let showAddButton: Bool
    private let addButton: AnyView?
    private let urls: [URL]

    public init(showAddButton: Bool = false, addButton: AnyView? = nil) {
        self.showAddButton = showAddButton
        self.addButton = addButton
        self.urls = Self.demoAudioFiles.map { URL(fileURLWithPath: "/demo/audio").appendingPathComponent($0) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: String.LocalizationValue("Total \(urls.count)"), bundle: .module))
                Spacer()

                if showAddButton, let addButton {
                    addButton
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            VStack(spacing: 0) {
                ForEach(urls, id: \.self) { url in
                    AudioItemDemo(url)
                }
            }
        }
    }
}
