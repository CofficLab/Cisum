import CisumUIComponents
import LumiUI
import SwiftUI

public struct WelcomeView: View {
    @LumiTheme private var appTheme
    private let isICloudAvailable: Bool
    private let currentStorageSelection: WelcomeStorageSelection?
    private let updateStorageSelection: @MainActor (WelcomeStorageSelection) -> Void

    public init(
        isICloudAvailable: Bool,
        currentStorageSelection: WelcomeStorageSelection?,
        updateStorageSelection: @escaping @MainActor (WelcomeStorageSelection) -> Void
    ) {
        self.isICloudAvailable = isICloudAvailable
        self.currentStorageSelection = currentStorageSelection
        self.updateStorageSelection = updateStorageSelection
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(appTheme.primary)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 8)

                Text("Choose Your Media Storage", bundle: .module)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(appTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Choose where Cisum stores your music and audiobooks. You can change this later in Settings.", bundle: .module)
                    .font(.title3)
                    .foregroundStyle(appTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            StorageView(
                isICloudAvailable: isICloudAvailable,
                currentStorageSelection: currentStorageSelection,
                updateStorageSelection: updateStorageSelection
            )
            .background(.regularMaterial)
            .cisumRoundedMedium()
            .cisumShadowSm()

            Spacer()
        }
        .padding(24)
    }
}
