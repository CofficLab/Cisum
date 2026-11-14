import Foundation
import SwiftUI

struct FileTitleView: View {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    var body: some View {
        HStack(spacing: 4) {
            FileIconView(url: url)

            Text(url.lastPathComponent)
        }
    }
}
