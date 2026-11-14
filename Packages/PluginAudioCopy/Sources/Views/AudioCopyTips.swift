import LumiUI
import ProviderAudioLibrary
import SwiftUI

struct AudioCopyTips: View {
    @LumiTheme private var appTheme
    enum Variant {
        case drop
        case pro
    }

    var variant: Variant = .drop

    /// 当前订阅档位的显示名。
    ///
    /// 经容量能力读取，不直接依赖商店服务：限额提示只关心「用户是什么档位」
    /// 这一个结论，不需要知道 StoreKit 的存在。
    var tierDisplayName: String = String(localized: "Free version", bundle: .module)

    var supportedFormats: [String] {
        AudioPluginInfo.supportedExtensions
    }

    var body: some View {
        ZStack {
            switch variant {
            case .drop:
                VStack(spacing: 24) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 48))
                        .foregroundStyle(appTheme.primary.opacity(0.7))

                    Text("Drag and drop music files here", bundle: .module)
                        .font(.title3)
                        .foregroundStyle(.primary)

                    // 格式展示
                    formatChipsView
                }
                .padding()
                .frame(maxWidth: .infinity)
                .appFillAvailableSpace()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(appTheme.primary, style: .init(lineWidth: 2, dash: [8, 6]))
                        )
                        .padding()
                )

            case .pro:
                VStack(spacing: 20) {
                    HStack {
                        Image.appInfo
                            .foregroundStyle(appTheme.primary)
                        Text(String(localized: String.LocalizationValue("Basic plan supports up to \(AudioPluginInfo.maxAudioCount) files"), bundle: .module))
                            .font(.title3)
                    }

                    // 优化后的格式展示
                    formatChipsView

                    HStack {
                        Text("Current subscription: ", bundle: .module) + Text(tierDisplayName)
                    }
                }
            }
        }
        .background(.regularMaterial)
        .shadowMd()
    }

    /// 格式标签视图
    private var formatChipsView: some View {
        VStack(spacing: 8) {
            Text("Supported Formats", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            HStack(spacing: 8) {
                ForEach(supportedFormats, id: \.self) { format in
                    HStack(spacing: 4) {
                        Image.appMusicNote
                            .font(.caption2)
                        Text(format.uppercased())
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(appTheme.primary.opacity(0.1))
                    .foregroundStyle(appTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}
