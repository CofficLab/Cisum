import LumiUI
import SwiftUI
import UniformTypeIdentifiers

/// 空仓库引导面板。
///
/// 呈现时机：仓库为空、且仓库视图收起（控制区占满窗口）时，出现在窗口顶部
/// 主要区域。只讲「怎么开始」——品牌区 + 一个醒目的拖放框；怎么打开仓库目录、
/// 怎么用「添加」导入属于操作说明，交给各处已有的入口，不在这里重复。
///
/// 拖放目标：窗口任意位置都可拖入，本面板把拖放区显式画出来，让新用户知道
/// 「拖到这里」是可行的。
struct RepositoryGuideView: View {
    @LumiTheme private var appTheme
    @ObservedObject private var importer: RepositoryGuideImporter

    init(importer: RepositoryGuideImporter) {
        self._importer = ObservedObject(wrappedValue: importer)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                dropZone
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollIndicators(.never)
    }

    // MARK: - 区块

    private var header: some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(appTheme.surface.opacity(0.72))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(appTheme.primary)
                }
                .shadowSm()

            Text(String(localized: "Start using Cisum", bundle: .module))
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(appTheme.textPrimary)

            Text(String(localized: "Put your music in the repository, and Cisum takes it from there", bundle: .module))
                .font(.system(size: 12.5))
                .foregroundStyle(appTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var dropZone: some View {
        VStack(spacing: 7) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(appTheme.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(appTheme.primary.opacity(0.12)))

            Text(String(localized: "Drop music files here", bundle: .module))
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(appTheme.textPrimary)

            Text(String(localized: "You can also drop them anywhere in the window", bundle: .module))
                .font(.system(size: 11.5))
                .foregroundStyle(appTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(appTheme.surface.opacity(importer.isDropping ? 0.75 : 0.42))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    appTheme.primary.opacity(importer.isDropping ? 0.7 : 0.3),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        }
        .contentShape(Rectangle())
        .onDrop(of: [UTType.fileURL], isTargeted: $importer.isDropping, perform: importer.handleDrop)
        .accessibilityIdentifier("cisum.repository.guide.dropzone")
    }
}
