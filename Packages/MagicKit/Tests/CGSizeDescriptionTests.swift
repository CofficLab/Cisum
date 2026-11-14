import CoreGraphics
import Testing

@testable import MagicKit

@Suite("CGSize description")
struct CGSizeDescriptionTests {
    @Test("keeps finite values compatible with existing integer formatting")
    func finiteDescription() {
        let size = CGSize(width: 12.8, height: 34.2)

        #expect(size.description == "12x34")
    }

    @Test("normalizes non-finite values instead of trapping")
    func nonFiniteDescription() {
        let size = CGSize(width: CGFloat.nan, height: CGFloat.infinity)

        #expect(size.description == "0x0")
    }

    @Test("preserves finite components when only one side is non-finite")
    func mixedFiniteDescription() {
        let size = CGSize(width: 42, height: -CGFloat.infinity)

        #expect(size.description == "42x0")
    }
}
