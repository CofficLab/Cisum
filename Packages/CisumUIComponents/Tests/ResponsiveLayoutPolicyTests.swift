import CoreGraphics
import SwiftUI
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

    @Test
    func progressPolicyNormalizesInvalidAndOutOfRangeValues() {
        #expect(MagicProgressBarPolicy.normalizedDuration(-1) == 0)
        #expect(MagicProgressBarPolicy.normalizedDuration(.infinity) == 0)
        #expect(MagicProgressBarPolicy.normalizedTime(.nan, duration: 10) == 0)
        #expect(MagicProgressBarPolicy.normalizedTime(-5, duration: 10) == 0)
        #expect(MagicProgressBarPolicy.normalizedTime(15, duration: 10) == 10)
        #expect(MagicProgressBarPolicy.normalizedTime(5, duration: 0) == 0)
        #expect(MagicProgressBarPolicy.normalizedProgress(currentTime: 2, duration: 8) == 0.25)
        #expect(MagicProgressBarPolicy.normalizedProgress(currentTime: 2, duration: 0) == 0)
    }

    @Test
    func seekPolicyClampsTrackCoordinatesAndRejectsInvalidGeometry() {
        #expect(MagicProgressBarPolicy.seekTime(locationX: 25, trackWidth: 100, duration: 80) == 20)
        #expect(MagicProgressBarPolicy.seekTime(locationX: -1, trackWidth: 100, duration: 80) == 0)
        #expect(MagicProgressBarPolicy.seekTime(locationX: 101, trackWidth: 100, duration: 80) == 80)
        #expect(MagicProgressBarPolicy.seekTime(locationX: 50, trackWidth: 0, duration: 80) == 0)
        #expect(MagicProgressBarPolicy.seekTime(locationX: .infinity, trackWidth: 100, duration: 80) == 0)
        #expect(MagicProgressBarPolicy.seekTime(locationX: 50, trackWidth: 100, duration: 0) == 0)
        #expect(MagicProgressBarPolicy.sliderUpperBound(forDuration: 0) == 1)
        #expect(MagicProgressBarPolicy.sliderUpperBound(forDuration: 90) == 90)
    }

    @Test
    func formattedTimeIsNonnegativeAndUsesMinuteSecondFormat() {
        #expect(MagicProgressBarPolicy.formattedTime(0) == "0:00")
        #expect(MagicProgressBarPolicy.formattedTime(65.9) == "1:05")
        #expect(MagicProgressBarPolicy.formattedTime(-1) == "0:00")
        #expect(MagicProgressBarPolicy.formattedTime(.nan) == "0:00")
    }

    @Test @MainActor
    func progressBarBindingClampsValuesAndReportsTheEffectiveSeekTime() {
        var currentTime: TimeInterval = 150
        var seekValues: [TimeInterval] = []
        let source = Binding(get: { currentTime }, set: { currentTime = $0 })
        let progressBinding = MagicProgressBarPolicy.normalizedTimeBinding(
            currentTime: source,
            duration: 100,
            onSeek: { seekValues.append($0) }
        )

        #expect(progressBinding.wrappedValue == 100)
        progressBinding.wrappedValue = -5
        #expect(currentTime == 0)
        progressBinding.wrappedValue = 42
        #expect(currentTime == 42)
        #expect(seekValues == [0, 42])

        let progressBar = MagicProgressBar(currentTime: source, duration: 100, onSeek: { _ in })
        _ = progressBar.body
    }
}
