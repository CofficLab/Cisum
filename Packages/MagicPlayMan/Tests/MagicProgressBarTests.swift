import CoreGraphics
import SwiftUI
import XCTest
@testable import MagicPlayMan

final class MagicProgressBarTests: XCTestCase {
    func testProgressPolicyNormalizesInvalidAndOutOfRangeValues() {
        XCTAssertEqual(MagicProgressBarPolicy.normalizedDuration(-1), 0)
        XCTAssertEqual(MagicProgressBarPolicy.normalizedDuration(.infinity), 0)
        XCTAssertEqual(MagicProgressBarPolicy.normalizedTime(.nan, duration: 10), 0)
        XCTAssertEqual(MagicProgressBarPolicy.normalizedTime(-5, duration: 10), 0)
        XCTAssertEqual(MagicProgressBarPolicy.normalizedTime(15, duration: 10), 10)
        XCTAssertEqual(MagicProgressBarPolicy.normalizedTime(5, duration: 0), 0)
        XCTAssertEqual(MagicProgressBarPolicy.normalizedProgress(currentTime: 2, duration: 8), 0.25)
        XCTAssertEqual(MagicProgressBarPolicy.normalizedProgress(currentTime: 2, duration: 0), 0)
    }

    func testSeekPolicyClampsCoordinatesAndRejectsInvalidGeometry() {
        XCTAssertEqual(MagicProgressBarPolicy.seekTime(locationX: 25, trackWidth: 100, duration: 80), 20)
        XCTAssertEqual(MagicProgressBarPolicy.seekTime(locationX: -1, trackWidth: 100, duration: 80), 0)
        XCTAssertEqual(MagicProgressBarPolicy.seekTime(locationX: 101, trackWidth: 100, duration: 80), 80)
        XCTAssertEqual(MagicProgressBarPolicy.seekTime(locationX: 50, trackWidth: 0, duration: 80), 0)
        XCTAssertEqual(MagicProgressBarPolicy.seekTime(locationX: .infinity, trackWidth: 100, duration: 80), 0)
        XCTAssertEqual(MagicProgressBarPolicy.seekTime(locationX: 50, trackWidth: 100, duration: 0), 0)
        XCTAssertEqual(MagicProgressBarPolicy.sliderUpperBound(forDuration: 0), 1)
        XCTAssertEqual(MagicProgressBarPolicy.sliderUpperBound(forDuration: 90), 90)
    }

    func testFormattedTimeIsNonnegativeAndUsesMinuteSecondFormat() {
        XCTAssertEqual(MagicProgressBarPolicy.formattedTime(0), "0:00")
        XCTAssertEqual(MagicProgressBarPolicy.formattedTime(65.9), "1:05")
        XCTAssertEqual(MagicProgressBarPolicy.formattedTime(-1), "0:00")
        XCTAssertEqual(MagicProgressBarPolicy.formattedTime(.nan), "0:00")
    }

    @MainActor
    func testProgressBarBindingClampsAndReportsEffectiveSeekTime() {
        var currentTime: TimeInterval = 150
        var seekValues: [TimeInterval] = []
        let source = Binding(get: { currentTime }, set: { currentTime = $0 })
        let progressBinding = MagicProgressBarPolicy.normalizedTimeBinding(
            currentTime: source,
            duration: 100,
            onSeek: { seekValues.append($0) }
        )

        XCTAssertEqual(progressBinding.wrappedValue, 100)
        progressBinding.wrappedValue = -5
        XCTAssertEqual(currentTime, 0)
        progressBinding.wrappedValue = 42
        XCTAssertEqual(currentTime, 42)
        XCTAssertEqual(seekValues, [0, 42])
        _ = MagicProgressBar(currentTime: source, duration: 100, onSeek: { _ in }).body
    }
}
