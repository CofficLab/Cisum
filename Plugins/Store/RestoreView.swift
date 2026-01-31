import MagicAlert
import MagicKit
import OSLog
import StoreKit
import SwiftUI

struct RestoreView: View, SuperEvent, SuperLog, SuperThread {
    @EnvironmentObject var app: AppProvider
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var m: MagicMessageProvider

    @State private var subscriptions: [Product] = []
    @State private var refreshing = false
    @State private var error: Error? = nil
    @State private var restoreState: RestoreState = .idle

    nonisolated static let emoji = "🖥️"
    nonisolated static let verbose = true

    init() {}

    var body: some View {
        SheetContainer {
            VStack(spacing: 16) {
                // 说明文字
                VStack(spacing: 16) {
                    // 插画区域
                    VStack(spacing: 0) {
                        ZStack {
                            // 背景圆形装饰
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.15),
                                            Color.cyan.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)

                            // 主图标（云同步/恢复）
                            Image(systemName: "icloud.and.arrow.down.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .frame(height: 120)
                    }
                    .padding(.top, 8)

                    // 标题区域
                    HStack(spacing: 12) {
                        Image.restart
                            .font(.title2)
                            .foregroundStyle(.blue)

                        Text("恢复购买")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            icon: "iphone.and.arrow.forward",
                            title: "跨设备恢复",
                            description: "在其他设备上购买后，可在此恢复"
                        )

                        InfoRow(
                            icon: "person.circle",
                            title: "Apple ID 验证",
                            description: "请使用购买时的 Apple ID 账号"
                        )

                        InfoRow(
                            icon: "checkmark.circle",
                            title: "功能恢复",
                            description: "恢复成功后将获得所有已购买的功能"
                        )
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .background(.regularMaterial)
                .roundedMedium()
                .shadowSm()

                // 状态提示区域
                if restoreState != .idle {
                    statusBanner
                }

                // 按钮区域
                successButtons
                    .if(self.restoreState == .success)

                restoreButton
                    .if(self.restoreState == .failed || self.restoreState == .idle)
            }.inMagicVStackCenter()
        }
    }

    // MARK: - View

    @ViewBuilder
    private var statusBanner: some View {
        switch restoreState {
        case .idle:
            EmptyView()
        case .restoring:
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在恢复购买")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("请稍候，正在验证您的购买记录...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial)
            .roundedMedium()
            .shadowSm()
        case .success:
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("恢复成功")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("已成功恢复您的购买记录，所有功能已解锁")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial)
            .roundedMedium()
            .shadowSm()
        case .failed:
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text("恢复失败")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let error = error {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("恢复购买时发生错误，请稍后重试")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial)
            .roundedMedium()
            .shadowSm()
        }
    }

    @ViewBuilder
    private var restoreButton: some View {
        HStack(spacing: 8) {
            switch restoreState {
            case .idle:
                Image.reset
                    .fontWeight(.semibold)
                Text("恢复购买")
                    .fontWeight(.semibold)
            case .restoring:
                EmptyView()
            case .success:
                EmptyView() // 成功状态使用 successButtons
            case .failed:
                Image.reset
                    .fontWeight(.semibold)
                Text("重试恢复")
                    .fontWeight(.semibold)
            }
        }
        .inCard(.regularMaterial)
        .hoverScale(restoreState == .idle || restoreState == .failed ? 105 : 1.0)
        .shadowSm()
        .inButtonWithAction {
            restorePurchase()
        }
        .disabled(restoreState == .restoring)
    }

    @ViewBuilder
    private var successButtons: some View {
        HStack(spacing: 12) {
            // 完成按钮
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .fontWeight(.semibold)
                Text("完成")
                    .fontWeight(.semibold)
            }
            .inCard(.regularMaterial)
            .hoverScale(105)
            .shadowSm()
            .inButtonWithAction {
                dismiss()
            }

            // 再试一次按钮
            HStack(spacing: 8) {
                Image.reset
                    .fontWeight(.semibold)
                Text("再试一次")
                    .fontWeight(.semibold)
            }
            .inCard(.regularMaterial)
            .hoverScale(105)
            .shadowSm()
            .inButtonWithAction {
                restoreState = .idle
                restorePurchase()
            }
        }
    }

    // MARK: - Actions

    private func restorePurchase() {
        restoreState = .restoring
        error = nil // 清除之前的错误
        Task {
            do {
                if Self.verbose {
                    os_log("\(self.t)🚀 开始恢复购买")
                }
                try await AppStore.sync()
                if Self.verbose {
                    os_log("\(self.t)✅ 恢复购买完成")
                }
                await MainActor.run {
                    restoreState = .success
                    error = nil // 清除错误信息
                    postRestore()
                }
            } catch {
                await MainActor.run {
                    restoreState = .failed
                    self.error = error
                    if Self.verbose {
                        os_log("\(self.t)❌ 恢复购买失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - Types

/// 恢复购买状态
private enum RestoreState {
    case idle // 恢复前
    case restoring // 恢复中
    case success // 恢复成功
    case failed // 恢复失败
}

// MARK: - Supporting Views

/// 信息行组件
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Event Emitter

extension RestoreView {
    func postRestore() {
        NotificationCenter.default.post(name: .Restored, object: nil)
    }
}

// MARK: - Preview

#Preview("Restore") {
    RestoreView()
        .inRootView()
        .withDebugBar()
}

#Preview("Debug") {
    DebugView()
        .inRootView()
        .withDebugBar()
}

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
