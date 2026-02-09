import Foundation
import SwiftData
import SwiftUI

@MainActor
struct AudioConfigRepo {
    static func getContainer() throws -> ModelContainer {
        let url = try Config.createDatabaseFile(name: "audio")

        let schema = Schema([
            AudioModel.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
