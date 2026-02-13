import SwiftUI

struct BtnDelDevice: View {
    @Environment(\.modelContext) private var modelContext
    
    @State var hovered = false

    var deviceData: DeviceData
    var autoResize = false

    var body: some View {
//        ControlButton(
//            title: "删除设备",
//            image: getImageName(),
//            dynamicSize: autoResize,
//            onTap: {
////                Task {
////                    await DBSynced(Config.getSyncedContainer).deleteDevice(deviceData)
////                }
//            })
    }

    private func getImageName() -> String {
        return "trash"
    }
}

#Preview("App") {
    ContentView()
    .inRootView()
        .frame(height: 800)
}


