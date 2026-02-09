import WidgetKit
import SwiftUI

struct CisumWidget: Widget {
    let kind: String = "CisumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CisumWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Cisum Widget")
        .description("Quick access to Cisum.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabledIfAvailable()
    }
}

extension WidgetConfiguration {
    func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
        if #available(iOS 17.0, macOS 14.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
    }
}
