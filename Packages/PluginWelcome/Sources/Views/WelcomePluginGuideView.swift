import CisumUIComponents
import LumiUI
import SwiftUI

struct WelcomePluginGuideView: View {
    var body: some View {
        WelcomeView(
            isICloudAvailable: WelcomePluginHost.isICloudAvailable,
            currentStorageSelection: WelcomePluginHost.currentStorageSelection,
            updateStorageSelection: { selection in
                WelcomePluginHost.updateStorageSelection(selection)
            }
        )
    }
}
