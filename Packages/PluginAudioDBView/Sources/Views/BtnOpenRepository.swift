import MagicKit
import SwiftUI

/// 「打开仓库目录」按钮：与「添加」按钮并排放在仓库列表表头右侧。
///
/// 点击后在系统文件管理器中打开音频仓库根目录（macOS 访达），
/// 用户可以直接把文件丢进目录入库，不必先走文件选择器。
///
/// 平台说明：iOS 上应用容器目录没有暴露给「文件」App
/// （Info.plist 未开启 `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace`），
/// 打开动作必然失败，因此 iOS 端不渲染该按钮；空仓库场景由空状态视图里的
/// 「打开仓库目录并放入文件」入口承担。
@MainActor
struct BtnOpenRepository: View {
    let dependencies: AudioDBDependencies

    var body: some View {
        button
    }

    @ViewBuilder
    private var button: some View {
        #if os(macOS)
            let disk = dependencies.audioDisk()

            Button(
                action: { disk?.openFolder() },
                label: {
                    Label(
                        title: { Text("Open repository folder", bundle: .module) },
                        icon: { Image(systemName: "folder") }
                    )
                }
            )
            .disabled(disk == nil)
            .help(Text("Open repository folder", bundle: .module))
        #else
            EmptyView()
        #endif
    }
}
