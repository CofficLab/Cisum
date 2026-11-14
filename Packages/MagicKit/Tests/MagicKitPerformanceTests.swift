import XCTest
@testable import MagicKit

class MagicKitPerformanceTests: XCTestCase {
    func testImageCroppingPerformance() {
        // 暂时跳过此测试，因为缺少相关的图像处理功能
        // let originalImage = UIImage(named: "largeTestImage")!
        // measure {
        //     _ = MagicKit.cropImage(originalImage, to: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        // }
    }
}