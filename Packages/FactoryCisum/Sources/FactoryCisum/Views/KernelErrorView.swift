import CisumKernel
import SwiftUI

/// 内核启动错误视图。
struct KernelErrorView: View {
    let error: Error

    /// 若错误由插件抛出，取出插件 ID 单独展示，便于定位问题来源。
    private var pluginID: String? {
        if case .pluginFailed(let pluginID, _) = error as? CisumKernelError {
            return pluginID
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Unable to start Cisum", bundle: .module)
                .font(.title2)
            if let pluginID {
                Text(pluginID)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(.white)
                    .background(.red.opacity(0.85), in: Capsule())
                    .allowsHitTesting(false)
            }
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
