import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

public extension MagicPlayMan {
    /// 订阅者列表视图
    struct SubscribersView: View {
        let subscribers: [PlaybackEvents.Subscriber]

        @Environment(\.localization) private var loc

        public var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.eventSubscribers)
                    .font(.headline)

                if subscribers.isEmpty {
                    ContentUnavailableView(
                        loc.noSubscribers,
                        systemImage: PlaybackSymbol.personGroupSlash,
                        description: Text(loc.noSubscribersRegistered)
                    )
                } else {
                    subscribersList
                }
            }
        }

        private var subscribersList: some View {
            List {
                ForEach(subscribers, id: \.id) { subscriber in
                    SubscriberRow(subscriber: subscriber)
                }
            }
            .listStyle(.plain)
        }
    }

    /// 订阅者行视图
    private struct SubscriberRow: View {
        let subscriber: PlaybackEvents.Subscriber

        @Environment(\.localization) private var loc

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(subscriber.name)
                    .font(.headline)

                Text("\(loc.since): \(subscriber.date.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}
