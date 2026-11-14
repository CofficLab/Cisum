import Foundation
import Testing
@testable import MagicKit

@Test func timeFormatterFormatsValidDurations() {
    #expect(TimeInterval(0).displayFormat == "0:00")
    #expect(TimeInterval(30).displayFormat == "0:30")
    #expect(TimeInterval(65).displayFormat == "1:05")
    #expect(TimeInterval(3665).displayFormat == "1:01:05")
}

@Test func timeFormatterNormalizesInvalidDurations() {
    #expect(TimeFormatter.format(.nan) == "0:00")
    #expect(TimeFormatter.format(.infinity) == "0:00")
    #expect(TimeFormatter.format(-12) == "0:00")
}
