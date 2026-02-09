import SwiftData
import SwiftUI

struct OperationView: View {
    @EnvironmentObject var playMan: PlayMan

    var asset: URL? { playMan.currentURL }
    var characterCount: Int { asset?.title.count ?? 0 }
    var geo: GeometryProxy

    var body: some View {
        HStack(spacing: 0, content: {
            Spacer()
            if let asset = asset {
                playMan.makeLikeButtonView()
                if Config.isDesktop {
                    asset.makeOpenButton()
                }
            }
            Spacer()
        })
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .labelStyle(.iconOnly)
    }

    func getFont() -> Font {
        if geo.size.height < 100 {
            return .title3
        }

        if geo.size.height < 200 {
            return .title2
        }

        return .title
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
