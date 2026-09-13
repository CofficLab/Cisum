import Foundation
import SwiftData
import SwiftUI

public struct AudioConfigRepo {
    public static func getContainer(databaseURL: URL) throws -> ModelContainer {
        let schema = Schema([
            AudioModel.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: databaseURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
