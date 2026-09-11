import CoreFoundation
import Darwin
import Foundation
import CisumUIComponents
import MagicPlayMan
import OSLog
import ProviderPlayback
import SwiftUI

public typealias AudioWidgetAdjacentAssetProvider = @MainActor (_ current: URL?, _ verbose: Bool) async throws -> URL?
public typealias AudioWidgetFirstAssetProvider = @MainActor () async throws -> URL?
public typealias AudioWidgetLastAssetProvider = @MainActor () async throws -> URL?

enum AudioWidgetPlayPauseAction {
    case play
    case pause
}

enum AudioWidgetPlaybackRequestPolicy {
    static func shouldApplyNavigationResult(requestedAsset: URL, currentAsset: URL?) -> Bool {
        representsSameFile(requestedAsset, currentAsset)
    }

    static func shouldWaitForPreviousNavigation(hasPreviousTask: Bool) -> Bool {
        hasPreviousTask
    }

    static func commandCount(from storedValue: Any?, maximum: Int = 10) -> Int {
        if let number = storedValue as? NSNumber {
            let doubleValue = number.doubleValue
            guard doubleValue.isFinite else { return 0 }

            if doubleValue > 1_000_000 {
                return 1
            }

            return min(max(Int(doubleValue), 0), maximum)
        }

        if let count = storedValue as? Int {
            return min(max(count, 0), maximum)
        }

        if let timestamp = storedValue as? TimeInterval, timestamp.isFinite {
            return 1
        }

        return 0
    }

    static func remainingCommandCount(afterConsuming consumedCount: Int, storedValue: Any?) -> Int {
        max(0, commandCount(from: storedValue, maximum: 1_000_000) - consumedCount)
    }

    static func playPauseAction(currentState: PlaybackStatus, commandCount: Int) -> AudioWidgetPlayPauseAction? {
        guard commandCount > 0, commandCount.isMultiple(of: 2) == false else {
            return nil
        }

        return currentState == .playing ? .pause : .play
    }

    private static func representsSameFile(_ lhs: URL?, _ rhs: URL?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return lhs.isSameFileLocation(as: rhs)
        default:
            return false
        }
    }
}

enum AudioWidgetCommandStore {
    static let suiteName = "group.com.yueyi.cisum"

    static func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        guard let lockURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("widget-command.lock") else {
            return try operation()
        }

        FileManager.default.createFile(atPath: lockURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: lockURL) else {
            return try operation()
        }

        flock(handle.fileDescriptor, LOCK_EX)
        defer {
            flock(handle.fileDescriptor, LOCK_UN)
            try? handle.close()
        }

        return try operation()
    }
}

public struct AudioWidgetControlRootView: View {
    @ObservedObject private var viewModel: AudioWidgetControlViewModel

    init(viewModel: AudioWidgetControlViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        EmptyView()
            .onAppear {
                viewModel.handleWidgetCommands()
            }
    }
}
