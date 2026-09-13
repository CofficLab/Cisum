import CisumUIComponents
import SwiftUI

struct BtnAdd: View {
    let dependencies: AudioDBDependencies

    var body: some View {
        Button(
            action: { dependencies.isImporting.wrappedValue = true },
            label: {
                Label(
                    title: { Text("Add", bundle: .module) },
                    icon: { Image(systemName: "plus.circle") }
                )
            }
        )
    }
}
