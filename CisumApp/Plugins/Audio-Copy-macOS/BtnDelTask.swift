import SwiftUI

struct BtnDelTask: View {
    @Environment(\.modelContext) private var context
    @State var hovered = false

    var tasks: Set<CopyTask>
    var autoResize = false

    var body: some View {
//        ControlButton(
//            title: "删除 \(tasks.count) 个",
//            image: getImageName(),
//            dynamicSize: autoResize,
//            onTap: {
//                for task in tasks {
//                    Task {
//                        context.delete(task)
//                    }
//                }
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


