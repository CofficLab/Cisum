import MagicKit
import OSLog
import SwiftUI

struct StorageView: View, SuperLog {
    nonisolated static let emoji = "🍴"
    static let verbose = true

    @EnvironmentObject var cloudManager: CloudProvider
    @EnvironmentObject var a: AppProvider

    @State private var tempStorageLocation: StorageLocation

    private var c = Config.self

    init() {
        _tempStorageLocation = State(initialValue: StorageLocation.icloud)
    }

    var body: some View {
        MagicSettingSection(title: "媒体仓库位置", titleAlignment: .center) {
            VStack(spacing: 12) {
                MagicSettingRow(
                    title: "iCloud 云盘",
                    description: "文件存储在 iCloud 中\n可在其他设备上访问\n确保 iCloud 存储空间足够",
                    icon: .iconCloud,
                    action: {
                        if cloudManager.isSignedIn == true && c.getStorageLocation() != .icloud {
                            tempStorageLocation = .icloud
                        }
                    }
                ) {
                    HStack {
                        if tempStorageLocation == .icloud {
                            Image(systemName: .iconCheckmarkSimple)
                                .foregroundColor(.accentColor)
                        } else {
                            Text("推荐").font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .opacity(cloudManager.isSignedIn == true ? 1 : 0.5)
                .disabled(cloudManager.isSignedIn != true)

                if cloudManager.isSignedIn != true {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .imageScale(.small)
                        Text("在系统设置中登录 iCloud 账户后，此选项可用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 32)
                    .padding(.bottom, 8)
                }

                Divider()

                MagicSettingRow(
                    title: "APP 内部存储",
                    description: "存储在 APP 中，删除 APP 后数据将丢失",
                    icon: .iconFolder,
                    action: {
                        tempStorageLocation = .local
                    }
                ) {
                    HStack {
                        if tempStorageLocation == .local {
                            Image(systemName: .iconCheckmarkSimple)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
        }
    }

    // MARK: - 自动设置存储位置

    private func autoSetStorageLocation() {
        // 如果已经有存储位置设置，则使用现有设置
        if let currentLocation = c.getStorageLocation() {
            tempStorageLocation = currentLocation
            return
        }
    }
}

// MARK: - Events Handling

extension StorageView {
    func onDisappear() {
        c.updateStorageLocation(tempStorageLocation)
    }

    func onAppear() {
        autoSetStorageLocation()
    }
}

// MARK: - Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
