import CisumUIComponents
import SwiftUI

struct AudioDemoAddButton: View {
    let isImporting: Binding<Bool>

    var body: some View {
        Button(
            action: { isImporting.wrappedValue = true },
            label: {
                Label(
                    title: { Text("Add", bundle: .module) },
                    icon: { Image(systemName: "plus.circle") }
                )
            }
        )
    }
}
