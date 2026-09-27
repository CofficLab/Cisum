import Foundation
import Testing
@testable import CisumUIComponents

struct ResponsiveLayoutPolicyTests {
    @Test
    func playerLayoutMetricsRespectSizingThresholds() {
        #expect(CisumPlayerLayout.defaultWindowSize == CGSize(width: 400, height: 360))
        #expect(CisumPlayerLayout.stateHeight(for: 250) == 24)
        #expect(CisumPlayerLayout.stateHeight(for: 251) == 36)
        #expect(CisumPlayerLayout.stateHeight(for: 450) == 36)
        #expect(CisumPlayerLayout.stateHeight(for: 451) == 48)
        #expect(CisumPlayerLayout.controlButtonHeight(width: 500, height: 400) == 100)
        #expect(CisumPlayerLayout.controlButtonHeight(width: 100, height: 100) == 20)
        #expect(CisumPlayerLayout.controlButtonHeight(width: -1, height: 100) == 0)
        #expect(!CisumPlayerLayout.shouldShowRightAlbum(width: 768))
        #expect(CisumPlayerLayout.shouldShowRightAlbum(width: 768.1))
        #expect(CisumPlayerLayout.needsExpandedWindow(for: 450))
        #expect(!CisumPlayerLayout.needsExpandedWindow(for: 451))
    }

}
