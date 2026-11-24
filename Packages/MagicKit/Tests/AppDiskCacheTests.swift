import XCTest
@testable import MagicKit

final class AppDiskCacheTests: XCTestCase {
    func testObjectsDirectoryUsesDiskCacheBucketLayout() {
        let bucketID = "com.example.cache.thumbnails"
        let url = AppDiskCache.objectsDirectory(bucketID: bucketID)

        XCTAssertTrue(url.path.hasSuffix("/DiskCache/\(bucketID)/objects"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testObjectsDirectoryIsStableAcrossCalls() {
        let bucketID = "com.example.cache.http"

        XCTAssertEqual(
            AppDiskCache.objectsDirectory(bucketID: bucketID).path,
            AppDiskCache.objectsDirectory(bucketID: bucketID).path
        )
    }
}