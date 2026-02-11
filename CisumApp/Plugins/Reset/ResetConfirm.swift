import MagicKit
import OSLog
import SwiftUI

struct ResetConfirm: View, SuperLog {
    @Environment(\.dismiss) private var dismiss

    @State private var isResetting: Bool = false

    nonisolated static let verbose = false
    nonisolated static let emoji = "👔"

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
                                            Color.orange.opacity(0.15),
                                            Color.red.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)

                            // 主图标（重置/警告）
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .frame(height: 120)
                    }
                    .padding(.top, 8)

                    // Title area
                    HStack(spacing: 12) {
                        Image(systemName: .iconReset)
                            .font(.title2)
                            .foregroundStyle(.orange)

                        Text("Reset Settings")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Spacer()
                    }

                    if isResetting {
                        // Resetting state
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.9)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Resetting…")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Restoring default settings, please wait")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        // Reset description
                        VStack(alignment: .leading, spacing: 12) {
                            ResetInfoRow(
                                icon: "externaldrive.fill",
                                title: "Data Storage Reset",
                                description: "Data storage will be restored to default location"
                            )

                            ResetInfoRow(
                                icon: "slider.horizontal.3",
                                title: "Preferences Reset",
                                description: "All user preferences will be reset"
                            )

                            ResetInfoRow(
                                icon: "exclamationmark.triangle.fill",
                                title: "Irreversible",
                                description: "This action cannot be undone, proceed with caution"
                            )
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .roundedMedium()
                .shadowSm()

                // Confirm button
                HStack(spacing: 8) {
                    Image.checkmark
                    Text("Continue Reset")
                }
                .inCard(.regularMaterial)
                .hoverScale(105)
                .shadowSm()
                .inButtonWithAction {
                    performReset()
                }
                .if(!isResetting)
            }.inMagicVStackCenter()
        }
    }

    // MARK: - Actions

    private func performReset() {
        isResetting = true

        Task {
            if Self.verbose {
                os_log("\(Self.t)🔄 开始重置设置")
            }

            // 短暂延迟，让用户看到重置中的状态
            try? await Task.sleep(nanoseconds: 2000000000) // 2秒

            // 执行重置操作
            Config.resetStorageLocation()

            if Self.verbose {
                os_log("\(Self.t)✅ 重置设置完成")
            }

            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views

/// 信息行组件
private struct ResetInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.orange)
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

// MARK: - Preview

#Preview("ResetConfirm") {
    ResetConfirm()
        .inRootView()
        .withDebugBar()
}

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
