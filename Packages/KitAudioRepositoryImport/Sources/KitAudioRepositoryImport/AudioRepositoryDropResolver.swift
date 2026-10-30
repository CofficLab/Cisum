import Foundation
import UniformTypeIdentifiers

/// 把拖放来源（`NSItemProvider`）解析成文件 URL。
///
/// 拖放解析涉及异步回调与 `NSItemProvider` 的非 Sendable 特性，
/// 放在 Kit 里集中处理，避免每个插件各写一份。
public enum AudioRepositoryDropResolver {
    /// 解析一批拖放来源，返回成功解析的 URL 与失败原因。
    public nonisolated static func droppedFileURLs(
        from providers: [NSItemProvider]
    ) async -> (urls: [URL], errors: [Error]) {
        var urls: [URL] = []
        var errors: [Error] = []

        for provider in providers {
            do {
                if let url = try await droppedFileURL(from: provider) {
                    urls.append(url)
                }
            } catch {
                errors.append(error)
            }
        }

        return (urls, errors)
    }

    /// 解析单个拖放来源；无法解析出文件 URL 时返回 `nil`。
    public nonisolated static func droppedFileURL(from provider: NSItemProvider) async throws -> URL? {
        var fileURLDataError: Error?

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            do {
                let data: Data? = try await withCheckedThrowingContinuation { continuation in
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: data)
                        }
                    }
                }

                if let data, let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
                    return url
                }
            } catch {
                fileURLDataError = error
            }
        }

        if let url = try await droppedURLObject(from: provider) {
            return url
        }

        if let fileURLDataError {
            throw fileURLDataError
        }

        return nil
    }

    private nonisolated static func droppedURLObject(from provider: NSItemProvider) async throws -> URL? {
        guard provider.canLoadObject(ofClass: URL.self) else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: object)
                }
            }
        }
    }
}
