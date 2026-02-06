import SwiftUI
import WidgetKit

struct CisumWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 10) {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: 24))
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 24))
            }
            .foregroundColor(.white)
            .padding(.bottom, 2)
            
            Text("Cisum")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if family != .systemSmall {
                Text("Music & Books Collection")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 4)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 255/255, green: 140/255, blue: 0/255), // DarkOrange
                    Color(red: 148/255, green: 0/255, blue: 211/255)  // DarkViolet
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            background(backgroundView)
        }
    }
}

#Preview(as: .systemSmall) {
    CisumWidget()
} timeline: {
    SimpleEntry(date: .now)
}

#Preview(as: .systemMedium) {
    CisumWidget()
} timeline: {
    SimpleEntry(date: .now)
}
