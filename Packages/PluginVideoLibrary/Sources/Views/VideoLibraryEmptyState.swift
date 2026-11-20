import LumiUI
import SwiftUI

struct VideoLibraryEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        if let actionTitle, let action {
            AppEmptyState(
                icon: icon,
                title: title,
                description: message,
                actionTitle: actionTitle,
                action: action
            )
        } else {
            AppEmptyState(icon: icon, title: title, description: message)
        }
    }
}
