import MagicKit
import SwiftUI

struct CrashedView: View {
    @EnvironmentObject var cloud: CloudProvider

    var error: Error

    @State private var showAlert = false
    @State private var isCopied = false

    var body: some View {
        ScrollView {
            VStack {
                Spacer(minLength: 20)

                Image.makeCoffeeReelIcon(useDefaultBackground: false)
                    .scaledToFit()
                    .background(
                        Circle()
                            .fill(.red.opacity(0.1))
                    )
                    .frame(maxHeight: 120)

                Spacer()

                VStack {
                    Text("遇到问题无法继续运行", tableName: "Core")
                        .font(.title)
                        .padding(.bottom, 10)

                    GroupBox {
                        Text(String(describing: type(of: error)))
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                            .font(.title2)

                        Text("\(error.localizedDescription)", tableName: "Core")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.bottom, 10)

                        // 复制错误信息按钮
                        Button(action: {
                            copyErrorToClipboard()
                        }) {
                            HStack {
                                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .foregroundColor(isCopied ? .green : .blue)
                                Text(isCopied ? "已复制" : "复制错误信息", tableName: "Core")
                                    .foregroundColor(isCopied ? .green : .blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                                    .stroke(isCopied ? Color.green : Color.blue, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(isCopied ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCopied)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                    }.padding()

                    Spacer()

                    debugView

                    #if os(macOS)
                        Button {
                            NSApplication.shared.terminate(self)
                        } label: {
                            Text("退出", tableName: "Core")
                        }.controlSize(.extraLarge)

                        Spacer()
                    #endif
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.opacity(0.8))
    }

    var debugView: some View {
        VStack(spacing: 10) {
            Section(content: {
                GroupBox {
                    makeKeyValueItem(key: String(localized: "启用iCloud云盘", table: "Core"), value: MagicApp.isICloudAvailable() ? String(localized: "是", table: "Core") : String(localized: "否", table: "Core"))
                    Divider()
                    makeKeyValueItem(key: String(localized: "登录 iCloud", table: "Core"), value: cloud.isSignedInDescription)
                }
            }, header: { makeTitle("iCloud") })

            Section(content: {
                GroupBox {
                    makeKeyValueItem(key: String(localized: "仓库位置", table: "Core"), value: Config.getStorageLocation()?.title ?? String(localized: "未设置", table: "Core"))
                }
            }, header: { makeTitle("设置") })

            Section(content: {
                GroupBox {
                    makeKeyValueItem(key: String(localized: "APP 容器", table: "Core"), value: MagicApp.getContainerDirectory().path(percentEncoded: false))
                    makeKeyValueItem(key: String(localized: "数据库文件夹", table: "Core"), value: MagicApp.getDatabaseDirectory().path(percentEncoded: false))
                }
            }, header: { makeTitle("文件夹") })

            GroupBox {
                Button {
                    Config.resetStorageLocation()
                    showAlert = true
                } label: {
                    Text("恢复默认设置", tableName: "Core")
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("提示", tableName: "Core"),
                        message: Text("请退出 APP，再重新打开", tableName: "Core"),
                        dismissButton: .default(Text("确定", tableName: "Core"))
                    )
                }
            }
        }.padding(20)
    }

    private func makeTitle(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title, tableName: "Core").font(.headline).padding(.leading, 10)
            Spacer()
        }
    }

    private func makeKeyValueItem(key: String, value: String) -> some View {
        HStack(content: {
            VStack(alignment: .leading, spacing: 5) {
                Text(key)
                Text(value)
                    .font(.footnote)
                    .opacity(0.8)
            }
            Spacer()
        }).padding(5)
    }

    /// 复制错误信息到剪贴板
    private func copyErrorToClipboard() {
        let errorInfo = """
        错误类型: \(String(describing: type(of: error)))
        错误描述: \(error.localizedDescription)
        """

        errorInfo.copy()

        // 显示复制成功状态
        withAnimation {
            isCopied = true
        }

        // 2秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - Private Helpers

extension CrashedView {
    private func isFileExist(_ url: URL) -> String {
        FileManager.default.fileExists(atPath: url.path) ? "是" : "否"
    }

    private func isDirExist(_ url: URL) -> String {
        var isDir: ObjCBool = true
        return FileManager.default.fileExists(atPath: url.path(), isDirectory: &isDir) ? "是" : "否"
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#if DEBUG
    #if os(macOS)
        #Preview("ErrorViewFatal - Large") {
            CrashedView(error: NSError(domain: "TestError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "这是一个测试错误，用于预览界面效果"]))
                .inRootView()
                .frame(width: 600, height: 1000)
        }

        #Preview("ErrorViewFatal - Small") {
            CrashedView(error: NSError(domain: "TestError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "测试错误"]))
                .inRootView()
                .frame(width: 500, height: 800)
        }
    #endif

    #if os(iOS)
        #Preview("ErrorViewFatal - iPhone") {
            CrashedView(error: NSError(domain: "TestError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "这是一个测试错误，用于预览界面效果"]))
                .inRootView()
        }
    #endif

    #Preview("App - Large") {
        ContentView()
            .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
            .inRootView()
            .frame(width: 500, height: 800)
    }

    #if os(iOS)
        #Preview("iPhone") {
            ContentView()
                .inRootView()
        }
    #endif
#endif
