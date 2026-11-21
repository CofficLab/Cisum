import AVFoundation
import CoreVideo
import Foundation

enum UITestVideoSeed {
    static func requestedFileNames(arguments: [String] = ProcessInfo.processInfo.arguments) -> [String] {
        guard arguments.contains("--cisum-ui-testing"),
              let index = arguments.firstIndex(of: "--cisum-ui-testing-seed-video"),
              arguments.indices.contains(index + 1) else { return [] }

        return arguments[index + 1]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { name in
                name.lowercased().hasSuffix(".mp4")
                    && !name.contains("/")
                    && !name.contains("\\")
                    && !name.contains(":")
            }
    }

    static func makeVideo(at url: URL, duration: TimeInterval = 2) async throws {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }

            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let width = 320
            let height = 180
            let frameRate: Int32 = 30
            let frameCount = max(1, Int((duration * TimeInterval(frameRate)).rounded()))
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                ]
            )
            guard writer.canAdd(input) else {
                throw writer.error ?? NSError(domain: "UITestVideoSeed", code: 1)
            }
            writer.add(input)
            guard writer.startWriting() else {
                throw writer.error ?? NSError(domain: "UITestVideoSeed", code: 2)
            }
            writer.startSession(atSourceTime: .zero)

            for frame in 0..<frameCount {
                while !input.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 1_000_000)
                }
                guard let pool = adaptor.pixelBufferPool else {
                    throw writer.error ?? NSError(domain: "UITestVideoSeed", code: 3)
                }
                var pixelBuffer: CVPixelBuffer?
                let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
                guard status == kCVReturnSuccess, let pixelBuffer else {
                    throw NSError(domain: "UITestVideoSeed", code: Int(status))
                }
                fill(pixelBuffer, width: width, height: height, frame: frame)
                guard adaptor.append(
                    pixelBuffer,
                    withPresentationTime: CMTime(value: Int64(frame), timescale: frameRate)
                ) else {
                    throw writer.error ?? NSError(domain: "UITestVideoSeed", code: 4)
                }
            }

            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else {
                throw writer.error ?? NSError(domain: "UITestVideoSeed", code: 5)
            }
        }.value
    }

    private static func fill(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int, frame: Int) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let red = UInt32((frame * 7) % 180 + 40)
        let color = UInt32(0xFF00_0000 | red << 16 | 80 << 8 | 160)

        for row in 0..<height {
            let rowAddress = baseAddress.advanced(by: row * bytesPerRow)
            for column in 0..<width {
                rowAddress.storeBytes(of: color, toByteOffset: column * 4, as: UInt32.self)
            }
        }
    }
}
