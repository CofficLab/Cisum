import MagicKit
import SwiftUI

struct AppStoreiOS: View {
    var body: some View {
        GeometryReader { geo in
            HStack {
                Group {
                    Text("适配 iOS")
                        .asPosterTitle()

                    VStack(spacing: 16) {
                        AppStoreFeatureItem(
                            icon: "icloud",
                            title: "云端同步",
                            description: "音乐库实时同步，随时随地访问"
                        )
                        AppStoreFeatureItem(
                            icon: "ipad.and.iphone",
                            title: "多设备同步",
                            description: "iPhone、iPad、Mac 数据无缝流转"
                        )
                        AppStoreFeatureItem(
                            icon: "shield",
                            title: "安全备份",
                            description: "自动备份到 iCloud，数据永不丢失"
                        )
                        AppStoreFeatureItem(
                            icon: "arrow.clockwise",
                            title: "自动同步",
                            description: "添加或修改后自动同步，无需手动操作"
                        )
                    }
                    .frame(width: geo.size.width * 0.4)
                    .py4()
                }
                .frame(width: geo.size.width * 0.5)
                .inMagicVStackCenter()

                Spacer()

                ZStack {
                    LogoView()
                        .background(Config.rootBackground)
                        .inIPadScreen()
                        .shadowSm()
                        .frame(height: geo.size.height * 0.8)
                        .roundedLarge()
                        .rotation3DEffect(
                            .degrees(-8),
                            axis: (x: 0, y: 0, z: 1),
                            anchor: .bottomLeading,
                            perspective: 1.0
                        )
                        .offset(x: -50, y: 0)

                    LogoView()
                        .background(Config.rootBackground)
                        .inIPhoneScreen()
                        .shadow3xl()
                        .frame(height: geo.size.height * 0.8)
                        .rotation3DEffect(
                            .degrees(4),
                            axis: (x: 0, y: 0, z: 1),
                            anchor: .bottomLeading,
                            perspective: 1.0
                        )
                        .offset(x: 150, y: -20)
                }
                .frame(width: geo.size.width * 0.5)
            }
        }
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store iOS") {
    AppStoreiOS()
        .inMagicContainer(.macBook13, scale: 0.5)
}
