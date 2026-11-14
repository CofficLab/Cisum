import Foundation
import Testing
@testable import MagicKit

@Test func relativeTimeFormatsPastAndFutureDates() {
    let now = Date(timeIntervalSince1970: 1_000_000)

    #expect(DateRelativeTimePolicy.relativeTime(for: now.addingTimeInterval(-30), now: now) == "just now")
    #expect(DateRelativeTimePolicy.relativeTime(for: now.addingTimeInterval(-60), now: now) == "1 minute ago")
    #expect(DateRelativeTimePolicy.relativeTime(for: now.addingTimeInterval(-300), now: now) == "5 minutes ago")
    #expect(DateRelativeTimePolicy.relativeTime(for: now.addingTimeInterval(-7200), now: now) == "2 hours ago")
    #expect(DateRelativeTimePolicy.relativeTime(for: now.addingTimeInterval(300), now: now) == "5 minutes from now")
}

@Test func relativeTimeNormalizesInvalidDates() {
    let invalid = Date(timeIntervalSince1970: .nan)

    #expect(DateRelativeTimePolicy.relativeTime(for: invalid) == "just now")
    #expect(DateRelativeTimePolicy.smartRelativeTime(for: invalid) == "just now")
}
